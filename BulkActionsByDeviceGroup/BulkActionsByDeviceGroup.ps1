function Invoke-IntuneDeviceAction {
<#
.SYNOPSIS
    Performs a bulk action on Intune devices sourced from an Entra group or a CSV file.
.DESCRIPTION
    This function targets devices for an action based on either their membership in an Entra ID group
    or a list of device names provided in a CSV file. It displays a progress bar during execution.
.EXAMPLE
    # Wipe all devices in the "HR Laptops" group, will prompt for confirmation.
    Invoke-IntuneDeviceAction -GroupName "HR Laptops" -Action Wipe

.EXAMPLE
    # SEE what would happen when running a remediation script on devices from a CSV file
    Invoke-IntuneDeviceAction -CsvPath "C:\temp\devices.csv" -Action "RunRemediation" -RemediationName "My Remediation" -WhatIf
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Group')]
        [string]$GroupName,

        [Parameter(Mandatory=$true, ParameterSetName='Csv')]
        [string]$CsvPath,
        
        # This parameter is now mandatory and has no default value.
        [Parameter(Mandatory=$true)]
        [ValidateSet("Retire", "Wipe", "Delete", "Sync", "Restart", "FreshStart", "RunRemediation")]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [string]$RemediationName,
        
        [Parameter(Mandatory=$false)]
        [int]$BatchSize = 100
    )

    # This helper function includes a progress bar.
    function Invoke-DeviceAction {
        param(
            [array]$Devices,
            [string]$Action,
            [int]$BatchSize,
            [string]$RemediationScriptId
        )
        $TotalDevices = $Devices.Count
        $OverallSuccessCount = 0

        if ($Action -eq "RunRemediation") {
            $activity = "Running Remediation: $($using:RemediationName)"
            $i = 0
            foreach ($Device in $Devices) {
                $i++
                $status = "Processing device $i of ${TotalDevices}: $($Device.DeviceName)"
                $percentComplete = ($i / $TotalDevices) * 100
                Write-Progress -Activity $activity -Status $status -PercentComplete $percentComplete

                Write-Verbose "Attempting to trigger remediation for: $($Device.DeviceName)"
                $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($Device.Id)')/initiateOnDemandProactiveRemediation"
                $Body = @{ scriptPolicyId = $RemediationScriptId } | ConvertTo-Json
                try { Invoke-MgGraphRequest -Method POST -Uri $Uri -Body $Body -ContentType "application/json"; Write-Verbose "  ✅ Success!"; $OverallSuccessCount++ } catch { Write-Warning "  ❌ Failed for device '$($Device.DeviceName)'. Error: $($_.Exception.Message)" }
                Start-Sleep -Seconds 1
            }
            Write-Progress -Activity $activity -Completed
            return $OverallSuccessCount
        }

        # --- Batch Processing with Progress Bar ---
        $TotalBatches = [Math]::Ceiling($TotalDevices / $BatchSize)
        $activity = "Performing bulk action: $Action"
        for ($BatchNumber = 1; $BatchNumber -le $TotalBatches; $BatchNumber++) {
            $StartIndex = ($BatchNumber - 1) * $BatchSize; $EndIndex = [Math]::Min($StartIndex + $BatchSize - 1, $TotalDevices - 1); $CurrentBatch = $Devices[$StartIndex..$EndIndex]
            
            $status = "Processing batch $BatchNumber of $TotalBatches ($($CurrentBatch.Count) devices)"
            $percentComplete = (($BatchNumber-1) / $TotalBatches) * 100
            Write-Progress -Activity $activity -Status $status -PercentComplete $percentComplete

            $DeviceIds = $CurrentBatch.Id
            $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/executeAction"
            switch ($Action) {
                "Retire"     { $Payload = @{ actionName = "retire"; keepUserData = $true; deviceIds  = $DeviceIds } }
                "Wipe"       { $Payload = @{ actionName = "wipe"; keepEnrollmentData = $false; keepUserData = $false; deviceIds = $DeviceIds } }
                "Delete"     { $Payload = @{ actionName = "delete"; deviceIds = $DeviceIds } }
                "Sync"       { $Payload = @{ actionName = "syncDevice"; deviceIds = $DeviceIds } }
                "Restart"    { $Payload = @{ actionName = "rebootNow"; deviceIds = $DeviceIds } }
                "FreshStart" { $Payload = @{ actionName = "cleanWindowsDevice"; keepUserData = $false; deviceIds = $DeviceIds } }
            }
            $JsonPayload = $Payload | ConvertTo-Json -Depth 10
            try { 
                Invoke-MgGraphRequest -Uri $Uri -Body $JsonPayload -Method POST -ContentType "Application/Json"
                Write-Verbose "✅ Batch ${BatchNumber}: '$Action' action initiated for $($CurrentBatch.Count) devices."
                $OverallSuccessCount += $CurrentBatch.Count
            } catch {
                Write-Warning "❌ Batch $BatchNumber failed: $($_.Exception.Message)"
            }

            if ($BatchNumber -lt $TotalBatches) { Start-Sleep -Seconds 2 }
        }
        Write-Progress -Activity $activity -Completed
        return $OverallSuccessCount
    }

    # --- SCRIPT LOGIC START ---
    Write-Verbose "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "Group.Read.All", "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementManagedDevices.PrivilegedOperations.All", "Directory.Read.All", "DeviceManagementConfiguration.Read.All" -NoWelcome

    try {
        # --- Parameter Validation ---
        if ($PSBoundParameters.ContainsKey('RemediationName') -and $Action -ne 'RunRemediation') {
            throw "The -RemediationName parameter can only be used when the -Action is 'RunRemediation'."
        }

        ## --- 1. Get Remediation Script ID first (if required) --- ##
        $RemediationScriptId = $null
        if ($Action -eq "RunRemediation") {
            if (-not $RemediationName) { throw "The '-RemediationName' parameter is required when Action is 'RunRemediation'." }
            Write-Verbose "Finding remediation script: '$RemediationName'..."
            $escapedRemediationName = $RemediationName -replace "'", "''"
            $remediationUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?`$filter=displayName eq '$escapedRemediationName'"
            $remediationResponse = Invoke-MgGraphRequest -Method GET -Uri $remediationUri
            $RemediationScript = $remediationResponse.value
            if (-not $RemediationScript) { throw "Remediation script '$RemediationName' not found!" }
            $RemediationScriptId = $RemediationScript[0].Id
            Write-Verbose "✅ Found remediation script with ID: $RemediationScriptId"
        }

        ## --- 2. Find Target Devices --- ##
        $IntuneDevices = [System.Collections.Generic.List[object]]::new()
        if ($PSCmdlet.ParameterSetName -eq 'Group') {
            Write-Verbose "Finding devices in group: $GroupName"
            $escapedGroupName = $GroupName -replace "'", "''"
            $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$escapedGroupName'"
            $groupResponse = Invoke-MgGraphRequest -Method GET -Uri $groupUri
            $Group = $groupResponse.value
            if (-not $Group) { throw "Group '$GroupName' not found!" }
            if ($Group.Count -gt 1) { throw "Multiple groups found with name '$GroupName'." }
            $Group = $Group[0]
            $DeviceMembers = [System.Collections.Generic.List[object]]::new()
            $membersUri = "https://graph.microsoft.com/v1.0/groups/$($Group.Id)/members/microsoft.graph.device"
            do { $membersResponse = Invoke-MgGraphRequest -Method GET -Uri $membersUri; $DeviceMembers.AddRange($membersResponse.value); $membersUri = $membersResponse.'@odata.nextLink' } while ($null -ne $membersUri)
            if ($DeviceMembers.Count -eq 0) { Write-Warning "No devices found in group '$GroupName'"; return }
            $azureAdDeviceIds = $DeviceMembers.DeviceId
            $batchParams = @{ Url = "/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '<placeholder>'"; Placeholder = $azureAdDeviceIds; PlaceholderAsId = $true }
            $batchRequest = New-GraphBatchRequest @batchParams
            $IntuneDevices = Invoke-GraphBatchRequest -batchRequest $batchRequest
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Csv') {
            Write-Verbose "Finding devices from CSV file: $CsvPath"
            if (-not (Test-Path -Path $CsvPath -PathType Leaf)) { throw "CSV file not found at path: $CsvPath" }
            $devicesFromCsv = Import-Csv -Path $CsvPath
            if (-not ($devicesFromCsv[0].PSObject.Properties.Name -contains 'DeviceName')) { throw "CSV file '$CsvPath' must contain a header named 'DeviceName'." }
            $deviceNamesFromCsv = $devicesFromCsv.DeviceName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
            $batchParams = @{ Url = "/deviceManagement/managedDevices?`$filter=deviceName eq '<placeholder>'"; Placeholder = $deviceNamesFromCsv }
            $batchRequest = New-GraphBatchRequest @batchParams
            $IntuneDevices = Invoke-GraphBatchRequest -batchRequest $batchRequest
        }

        ## --- 3. Process Results and Execute --- ##
        if ($IntuneDevices.Count -eq 0) { Write-Warning "No matching managed Intune devices were found."; return }
        
        Write-Host "`nFound $($IntuneDevices.Count) Intune managed devices to target." -ForegroundColor Green
        $IntuneDevices | ForEach-Object { Write-Host "  - $($_.DeviceName) ($($_.OperatingSystem))" }
        
        $target = "all $($IntuneDevices.Count) targeted devices"
        if ($PSCmdlet.ShouldProcess($target, "Perform action: '$Action'")) {
            $actionParams = @{
                Devices             = $IntuneDevices
                Action              = $Action
                BatchSize           = $BatchSize
                RemediationScriptId = $RemediationScriptId
            }
            $SuccessCount = Invoke-DeviceAction @actionParams
            
            Write-Host "`n🥳 Processing completed!" -ForegroundColor Green
            Write-Host "Action '$Action' was initiated for $SuccessCount out of $($IntuneDevices.Count) devices." -ForegroundColor Cyan
        }
    }
    catch {
        Write-Error "Script execution failed: $($_.Exception.Message)"
    }
    finally {
        Write-Verbose "`nDisconnecting from Microsoft Graph..."
        Disconnect-MgGraph
    }
}