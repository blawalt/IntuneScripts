#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement

<#
.SYNOPSIS
    Updates the Group Tag for Windows Autopilot devices from a list of serial numbers.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SerialNumberFile,

    [Parameter(Mandatory=$true)]
    [string]$NewGroupTag,

    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Connect to Microsoft Graph with the required permissions
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
try {
    
    
    Connect-MgGraph -Scopes @("DeviceManagementServiceConfig.ReadWrite.All")
    Write-Host "Successfully connected to tenant '$((Get-MgContext).TenantId)' using the BETA profile." -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Microsoft Graph. Please check your permissions and try again. Error: $($_.Exception.Message)"
    return
}

try {
    if (-not (Test-Path -Path $SerialNumberFile -PathType Leaf)) {
        throw "Input file not found at path: $SerialNumberFile"
    }

    $serialNumbers = Get-Content -Path $SerialNumberFile
    if ($serialNumbers.Count -eq 0) { throw "The specified file is empty or could not be read." }

    Write-Host "`nFound $($serialNumbers.Count) serial numbers to process with New Group Tag: '$NewGroupTag'" -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "`n[WHATIF MODE] Script is running in simulation mode. No changes will be made." -ForegroundColor Magenta
    }

    foreach ($serial in $serialNumbers) {
        $trimmedSerial = $serial.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmedSerial)) { continue }

        Write-Host "------------------------------------------------------------------"
        Write-Host "Processing Serial Number: $trimmedSerial"

        try {
            # Find the device using the beta endpoint you discovered.
            # NOTE: Using 'contains' is broader than 'eq'. The script relies on the count check below for safety.
            $findUri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=contains(serialNumber,'$trimmedSerial')"
            $deviceResponse = Invoke-MgGraphRequest -Method GET -Uri $findUri
            
            $autopilotDevice = $deviceResponse.value
            
            if ($null -ne $autopilotDevice -and $autopilotDevice.Count -eq 1) {
                $deviceId = $autopilotDevice[0].id
                $currentGroupTag = $autopilotDevice[0].groupTag
                Write-Host "  ✅ Found device with ID: $deviceId (Current Tag: '$currentGroupTag')" -ForegroundColor Green
                
                if ($WhatIf) {
                    Write-Host "  [WHATIF] Would update Group Tag to '$NewGroupTag'." -ForegroundColor Magenta
                    continue
                }

                 $groupTagBody = @{
        					"groupTag" = $NewGroupTag
    					} | ConvertTo-Json
            
            Write-Host "Adding the $NewGroupTag group tag to $($autopilotDevice[0].deviceName)."
            $apiUri = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$deviceId/UpdateDeviceProperties"
            Invoke-MgGraphRequest -Uri $apiUri -Method Post -ContentType 'application/json' -Body $groupTagBody

    
                
                Write-Host "  ✅ Successfully updated Group Tag to '$NewGroupTag'." -ForegroundColor Green

            }
            elseif ($null -ne $autopilotDevice -and $autopilotDevice.Count -gt 1) {
                Write-Warning "  ⚠️ Found multiple devices with serial number '$trimmedSerial'. Skipping for safety."
            }
            else {
                Write-Warning "  ⚠️ Device with serial number '$trimmedSerial' not found in Autopilot using the beta endpoint."
            }
        }
        catch {
            Write-Error "  ❌ An error occurred processing serial '$trimmedSerial': $($_.Exception.Message)"
        }
    }
}
catch {
    Write-Error "A critical error occurred: $($_.Exception.Message)"
}
finally {
    Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Yellow
    Disconnect-MgGraph
}

Write-Host "`nScript finished." -ForegroundColor Cyan