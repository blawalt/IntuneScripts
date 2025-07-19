# Bulk Device Action Script by Entra Group Membership
# Actions: Retire, Wipe, Delete, Sync, Restart, FreshStart, RunRemediation

param(
    [Parameter(Mandatory=$true)]
    [string]$GroupName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Retire", "Wipe", "Delete", "Sync", "Restart", "FreshStart", "RunRemediation")]
    [string]$Action = "Restart",

    [Parameter(Mandatory=$false)]
    [string]$RemediationName,
    
    [Parameter(Mandatory=$false)]
    [int]$BatchSize = 100,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# --- Main Action Function ---
# Handles both batched and per-device actions.
function Invoke-DeviceAction {
    param(
        [array]$Devices,
        [string]$Action,
        [int]$BatchSize,
        [string]$RemediationScriptId,
        [bool]$WhatIfMode = $false
    )
    
    $TotalDevices = $Devices.Count
    $OverallSuccessCount = 0

    # --- Per-Device Action for Proactive Remediation ---
    if ($Action -eq "RunRemediation") {
        Write-Host "`nProcessing $TotalDevices devices individually for '$Action'..." -ForegroundColor Cyan
        if ($WhatIfMode) {
            Write-Host "[WHATIF] Would run remediation '$($using:RemediationName)' on $TotalDevices devices." -ForegroundColor Magenta
            $Devices | ForEach-Object { Write-Host "  - $($_.DeviceName)" -ForegroundColor Gray }
            return $TotalDevices
        }
        foreach ($Device in $Devices) {
            Write-Host "Attempting to trigger remediation for: $($Device.DeviceName)" -ForegroundColor Cyan
            $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($Device.Id)')/initiateOnDemandProactiveRemediation"
            $Body = @{ scriptPolicyId = $RemediationScriptId } | ConvertTo-Json
            try {
                Invoke-MgGraphRequest -Method POST -Uri $Uri -Body $Body -ContentType "application/json"
                Write-Host "  ✅ Success!" -ForegroundColor Green
                $OverallSuccessCount++
            } catch {
                Write-Warning "  ❌ Failed for device '$($Device.DeviceName)'. Error: $($_.Exception.Message)"
            }
            Start-Sleep -Seconds 1
        }
        return $OverallSuccessCount
    }

    # --- Batch Processing Logic for all other actions ---
    $TotalBatches = [Math]::Ceiling($TotalDevices / $BatchSize)
    Write-Host "`nProcessing $TotalDevices devices in $TotalBatches batch(es) for action '$Action'..." -ForegroundColor Cyan
    for ($BatchNumber = 1; $BatchNumber -le $TotalBatches; $BatchNumber++) {
        $StartIndex = ($BatchNumber - 1) * $BatchSize
        $EndIndex = [Math]::Min($StartIndex + $BatchSize - 1, $TotalDevices - 1)
        $CurrentBatch = $Devices[$StartIndex..$EndIndex]
        Write-Host "`n--- Processing Batch $BatchNumber of $TotalBatches ---" -ForegroundColor Yellow
        if ($WhatIfMode) {
            Write-Host "[WHATIF] Would perform '$Action' on $($CurrentBatch.Count) devices." -ForegroundColor Magenta
            $CurrentBatch | ForEach-Object { Write-Host "  - $($_.DeviceName)" -ForegroundColor Gray }
            $OverallSuccessCount += $CurrentBatch.Count
            continue
        }
        $DeviceIds = $CurrentBatch.Id
        $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/executeAction"
        switch ($Action) {
            "Retire"     { $Payload = @{ action = "retire"; keepUserData = $true } }
            "Wipe"       { $Payload = @{ action = "wipe"; keepUserData = $false } }
            "Delete"     { $Payload = @{ action = "delete" } }
            "Sync"       { $Payload = @{ action = "syncDevice" } }
            "Restart"    { $Payload = @{ action = "rebootNow" } }
            "FreshStart" { $Payload = @{ action = "cleanWindowsDevice"; keepUserData = $false } }
        }
        $Payload.Add("deviceIds", $DeviceIds)
        $JsonPayload = $Payload | ConvertTo-Json -Depth 10
        try {
            Invoke-MgGraphRequest -Uri $Uri -Body $JsonPayload -Method POST -ContentType "Application/Json"
            Write-Host "✅ Batch ${BatchNumber}: '$Action' action initiated for $($CurrentBatch.Count) devices." -ForegroundColor Green
            $OverallSuccessCount += $CurrentBatch.Count
        } catch {
            Write-Warning "❌ Batch $BatchNumber failed: $($_.Exception.Message)"
        }
        if ($BatchNumber -lt $TotalBatches) { Start-Sleep -Seconds 2 }
    }
    return $OverallSuccessCount
}

# --- SCRIPT START ---
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -Scopes "Group.Read.All", "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementManagedDevices.PrivilegedOperations.All", "Directory.Read.All", "DeviceManagementConfiguration.Read.All"

try {
    # --- Action-Specific Checks ---
    $RemediationScriptId = $null
    if ($Action -eq "RunRemediation") {
        if (-not $RemediationName) {
            throw "The '-RemediationName' parameter is required when Action is 'RunRemediation'."
        }
        # Find the Remediation Script ID
        Write-Host "Finding remediation script: '$RemediationName'..." -ForegroundColor Cyan
        $escapedRemediationName = $RemediationName -replace "'", "''"
        $remediationUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?`$filter=displayName eq '$escapedRemediationName'"
        $remediationResponse = Invoke-MgGraphRequest -Method GET -Uri $remediationUri
        $RemediationScript = $remediationResponse.value
        if (-not $RemediationScript) { throw "Remediation script '$RemediationName' not found!" }
        $RemediationScriptId = $RemediationScript[0].Id
        Write-Host "✅ Found remediation script with ID: $RemediationScriptId" -ForegroundColor Green
    }

    # --- Find Group and Devices---
    Write-Host "Finding group: $GroupName" -ForegroundColor Yellow
    $escapedGroupName = $GroupName -replace "'", "''"
    $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$escapedGroupName'"
    $groupResponse = Invoke-MgGraphRequest -Method GET -Uri $groupUri
    $Group = $groupResponse.value
    if (-not $Group) { throw "Group '$GroupName' not found!" }
    if ($Group.Count -gt 1) { throw "Multiple groups found with name '$GroupName'." }
    $Group = $Group[0]

    Write-Host "Getting group members..." -ForegroundColor Yellow
    $DeviceMembers = [System.Collections.Generic.List[object]]::new()
    $membersUri = "https://graph.microsoft.com/v1.0/groups/$($Group.Id)/members/microsoft.graph.device"
    do {
        $membersResponse = Invoke-MgGraphRequest -Method GET -Uri $membersUri
        $DeviceMembers.AddRange($membersResponse.value)
        $membersUri = $membersResponse.'@odata.nextLink'
    } while ($null -ne $membersUri)
    if ($DeviceMembers.Count -eq 0) { Write-Warning "No devices found in group '$GroupName'"; return }
    
    Write-Host "Found $($DeviceMembers.Count) devices in group. Correlating to Intune via API calls..." -ForegroundColor Green
    $IntuneDevices = @()
    foreach ($Device in $DeviceMembers) {
        $entraDeviceDetailsUri = "https://graph.microsoft.com/v1.0/devices/$($Device.Id)"
        $DeviceDetails = Invoke-MgGraphRequest -Method GET -Uri $entraDeviceDetailsUri
        if (-not $DeviceDetails.deviceId) { continue }
        $intuneDeviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=azureADDeviceId eq '$($DeviceDetails.deviceId)'"
        $intuneDeviceResponse = Invoke-MgGraphRequest -Method GET -Uri $intuneDeviceUri
        if ($intuneDeviceResponse.value) { $IntuneDevices += $intuneDeviceResponse.value[0] }
    }
    if ($IntuneDevices.Count -eq 0) { Write-Warning "No managed Intune devices found for group members"; return }
    
    Write-Host "Found $($IntuneDevices.Count) Intune managed devices." -ForegroundColor Green
    Write-Host "`nDevices that will be affected:" -ForegroundColor Cyan
    $IntuneDevices | ForEach-Object { Write-Host "  - $($_.DeviceName) ($($_.OperatingSystem))" -ForegroundColor White }
    
    # --- Confirmation and Execution ---
    if (-not $WhatIf) {
        $Confirmation = Read-Host "`nAre you sure you want to perform '$Action' on these $($IntuneDevices.Count) devices? (y/N)"
        if ($Confirmation.ToLower() -ne 'y') { Write-Host "Operation cancelled." -ForegroundColor Yellow; return }
    }
    
    Write-Host "`nStarting '$Action' operations..." -ForegroundColor Yellow
    $SuccessCount = Invoke-DeviceAction -Devices $IntuneDevices -Action $Action -BatchSize $BatchSize -RemediationScriptId $RemediationScriptId -WhatIfMode $WhatIf
    
    Write-Host "`n🎉 Processing completed!" -ForegroundColor Green
    $ResultVerb = if ($WhatIf) { "would be" } else { "was" }
    Write-Host "Action '$Action' $ResultVerb initiated for $SuccessCount out of $($IntuneDevices.Count) devices." -ForegroundColor Cyan
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
}
finally {
    Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Yellow
    Disconnect-MgGraph
}