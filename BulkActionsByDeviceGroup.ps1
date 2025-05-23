# Bulk Retire Intune Devices by Entra Group Membership - Batched Version
# This script gets all devices from an Entra/Azure AD group and performs bulk retire action in batches

param(
    [Parameter(Mandatory=$true)]
    [string]$GroupName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Retire", "Wipe", "Delete", "Sync", "Restart", "FreshStart")]
    [string]$Action = "Restart",
    
    [Parameter(Mandatory=$false)]
    [int]$BatchSize = 500,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Import required modules
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.DeviceManagement

# Function to process devices in batches
function Invoke-BatchedDeviceAction {
    param(
        [array]$Devices,
        [string]$Action,
        [int]$BatchSize,
        [bool]$WhatIfMode = $false
    )
    
    $TotalDevices = $Devices.Count
    $TotalBatches = [Math]::Ceiling($TotalDevices / $BatchSize)
    $OverallSuccessCount = 0
    
    Write-Host "`nProcessing $TotalDevices devices in $TotalBatches batch(es) of up to $BatchSize devices each..." -ForegroundColor Cyan
    
    for ($BatchNumber = 1; $BatchNumber -le $TotalBatches; $BatchNumber++) {
        $StartIndex = ($BatchNumber - 1) * $BatchSize
        $EndIndex = [Math]::Min($StartIndex + $BatchSize - 1, $TotalDevices - 1)
        $CurrentBatch = $Devices[$StartIndex..$EndIndex]
        
        Write-Host "`n--- Processing Batch $BatchNumber of $TotalBatches (Devices $($StartIndex + 1) to $($EndIndex + 1)) ---" -ForegroundColor Yellow
        
        if ($WhatIfMode) {
            Write-Host "[WHATIF] Would perform '$Action' on $($CurrentBatch.Count) devices in this batch:" -ForegroundColor Magenta
            $CurrentBatch | ForEach-Object {
                Write-Host "  - $($_.DeviceName) ($($_.OperatingSystem)) - User: $($_.UserDisplayName)" -ForegroundColor Gray
            }
            $OverallSuccessCount += $CurrentBatch.Count
            continue
        }
        
        # Display devices in current batch
        Write-Host "Devices in this batch:" -ForegroundColor White
        $CurrentBatch | ForEach-Object {
            Write-Host "  - $($_.DeviceName) ($($_.OperatingSystem)) - User: $($_.UserDisplayName)" -ForegroundColor Gray
        }
        
        # Prepare batch payload
        $DeviceIds = $CurrentBatch | ForEach-Object { $_.Id }
        $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/executeAction"
        
        # Define action parameters based on action type
        switch ($Action) {
            "Retire" {
                $JsonPayload = @{
                    action = "retire"
                    keepEnrollmentData = $false
                    keepUserData = $true
                    platform = "all"
                    deviceIds = $DeviceIds
                    realAction = "retire"
                    actionName = "retire"
                }
            }
            "Wipe" {
                $JsonPayload = @{
                    action = "wipe"
                    keepEnrollmentData = $false
                    keepUserData = $false
                    platform = "all"
                    deviceIds = $DeviceIds
                    realAction = "wipe"
                    actionName = "wipe"
                }
            }
            "Delete" {
                $JsonPayload = @{
                    action = "delete"
                    platform = "all"
                    deviceIds = $DeviceIds
                    realAction = "delete"
                    actionName = "delete"
                }
            }
            "Sync" {
                $JsonPayload = @{
                    action = "syncDevice"
                    platform = "all"
                    deviceIds = $DeviceIds
                    realAction = "syncDevice"
                    actionName = "syncDevice"
                }
            }
            "Restart" {
                $JsonPayload = @{
                    action = "rebootNow"
                    platform = "all"
                    deviceIds = $DeviceIds
                    realAction = "rebootNow"
                    actionName = "rebootNow"
                }
            }
            "FreshStart" {
                $JsonPayload = @{
                    action = "freshStart"
                    keepEnrollmentData = $true
                    keepUserData = $false
                    platform = "all"
                    deviceIds = $DeviceIds
                    realAction = "freshStart"
                    actionName = "freshStart"
                }
            }
        }
        
        # Execute batch action with retry logic
        $BatchSuccessCount = 0
        $MaxRetries = 3
        $RetryCount = 0
        $BatchSucceeded = $false
        
        do {
            try {
                Write-Host "Executing batch $Action action (attempt $($RetryCount + 1)/$($MaxRetries + 1))..." -ForegroundColor Yellow
                
                $Json = $JsonPayload | ConvertTo-Json -Depth 10
                Invoke-MgGraphRequest -Uri $Uri -Body $Json -Method POST -ContentType "Application/Json"
                
                Write-Host "✅ Batch ${BatchNumber}: $Action action successfully initiated for $($CurrentBatch.Count) devices!" -ForegroundColor Green
                $BatchSuccessCount = $CurrentBatch.Count
                $BatchSucceeded = $true
                break
            }
            catch {
                $RetryCount++
                Write-Warning "❌ Batch $BatchNumber failed (attempt $RetryCount): $($_.Exception.Message)"
                
                if ($RetryCount -le $MaxRetries) {
                    $WaitTime = $RetryCount * 5
                    Write-Host "Waiting $WaitTime seconds before retry..." -ForegroundColor Yellow
                    Start-Sleep -Seconds $WaitTime
                } else {
                    Write-Error "Batch $BatchNumber failed after $($MaxRetries + 1) attempts. Falling back to individual device actions..."
                    
                    # Fallback to individual device actions for this batch
                    foreach ($Device in $CurrentBatch) {
                        try {
                            switch ($Action) {
                                "Retire" { 
                                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($Device.Id)/retire" -Method POST
                                }
                                "Sync" { 
                                    Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $Device.Id 
                                }
                                "Restart" { 
                                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($Device.Id)/rebootNow" -Method POST
                                }
                                "Wipe" {
                                    $WipeBody = @{ keepEnrollmentData = $false; keepUserData = $false } | ConvertTo-Json
                                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($Device.Id)/wipe" -Method POST -Body $WipeBody -ContentType "Application/Json"
                                }
                                "Delete" {
                                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($Device.Id)" -Method DELETE
                                }
                                "FreshStart" {
                                    $FreshStartBody = @{ keepUserData = $false } | ConvertTo-Json
                                    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($Device.Id)/cleanWindowsDevice" -Method POST -Body $FreshStartBody -ContentType "Application/Json"
                                }
                            }
                            Write-Host "  ✅ Individual $Action completed for: $($Device.DeviceName)" -ForegroundColor Green
                            $BatchSuccessCount++
                        }
                        catch {
                            Write-Warning "  ❌ Failed individual $Action for device: $($Device.DeviceName) - $($_.Exception.Message)"
                        }
                    }
                    break
                }
            }
        } while ($RetryCount -le $MaxRetries -and -not $BatchSucceeded)
        
        $OverallSuccessCount += $BatchSuccessCount
        
        # Add a small delay between batches to be nice to the API
        if ($BatchNumber -lt $TotalBatches) {
            Write-Host "Waiting 2 seconds before next batch..." -ForegroundColor Gray
            Start-Sleep -Seconds 2
        }
    }
    
    return $OverallSuccessCount
}

# Connect to Microsoft Graph with required permissions
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -Scopes @(
    "Group.Read.All",
    "DeviceManagementManagedDevices.ReadWrite.All", 
    "DeviceManagementManagedDevices.PrivilegedOperations.All",
    "Directory.Read.All"
)

try {
    # Get the group by name
    Write-Host "Finding group: $GroupName" -ForegroundColor Yellow
    $Group = Get-MgGroup -Filter "DisplayName eq '$GroupName'"
    
    if (-not $Group) {
        Write-Error "Group '$GroupName' not found!"
        return
    }
    
    if ($Group.Count -gt 1) {
        Write-Error "Multiple groups found with name '$GroupName'. Please use a more specific name."
        return
    }
    
    Write-Host "Found group: $($Group.DisplayName) (ID: $($Group.Id))" -ForegroundColor Green
    
    # Get all members of the group (devices only)
    Write-Host "Getting group members..." -ForegroundColor Yellow
    $GroupMembers = Get-MgGroupMember -GroupId $Group.Id -All
    
    # Filter for device objects only
    $DeviceMembers = $GroupMembers | Where-Object { 
        $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.device' 
    }
    
    if ($DeviceMembers.Count -eq 0) {
        Write-Warning "No devices found in group '$GroupName'"
        return
    }
    
    Write-Host "Found $($DeviceMembers.Count) devices in the group" -ForegroundColor Green
    
    # Get corresponding Intune managed devices
    Write-Host "Finding corresponding Intune managed devices..." -ForegroundColor Yellow
    $IntuneDevices = @()
    
    foreach ($Device in $DeviceMembers) {
        # Get device details from Entra
        $DeviceDetails = Get-MgDevice -DeviceId $Device.Id
        
        # Find corresponding Intune device by Azure AD Device ID
        $IntuneDevice = Get-MgDeviceManagementManagedDevice -Filter "azureADDeviceId eq '$($DeviceDetails.DeviceId)'"
        
        if ($IntuneDevice) {
            $IntuneDevices += $IntuneDevice
        } else {
            Write-Warning "Device '$($DeviceDetails.DisplayName)' not found in Intune or not managed"
        }
    }
    
    if ($IntuneDevices.Count -eq 0) {
        Write-Warning "No managed Intune devices found for group members"
        return
    }
    
    Write-Host "Found $($IntuneDevices.Count) Intune managed devices" -ForegroundColor Green
    
    # Calculate batch information
    $TotalBatches = [Math]::Ceiling($IntuneDevices.Count / $BatchSize)
    Write-Host "Will process devices in $TotalBatches batch(es) of up to $BatchSize devices each" -ForegroundColor Cyan
    
    # Display summary of devices that will be affected
    Write-Host "`nDevices that will be affected:" -ForegroundColor Cyan
    $IntuneDevices | ForEach-Object {
        Write-Host "  - $($_.DeviceName) ($($_.OperatingSystem)) - User: $($_.UserDisplayName)" -ForegroundColor White
    }
    
    if ($WhatIf) {
        Write-Host "`n[WHATIF MODE] - No actual changes will be made" -ForegroundColor Magenta
        $SuccessCount = Invoke-BatchedDeviceAction -Devices $IntuneDevices -Action $Action -BatchSize $BatchSize -WhatIfMode $true
        Write-Host "`n[WHATIF] Would perform '$Action' on $SuccessCount devices across $TotalBatches batch(es)" -ForegroundColor Magenta
        return
    }
    
    # Confirm action
    $Confirmation = Read-Host "`nAre you sure you want to perform '$Action' on these $($IntuneDevices.Count) devices in $TotalBatches batch(es)? (y/N)"
    if ($Confirmation -ne 'y' -and $Confirmation -ne 'Y') {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        return
    }
    
    # Perform the batched actions
    Write-Host "`nStarting batched $Action operations..." -ForegroundColor Yellow
    $SuccessCount = Invoke-BatchedDeviceAction -Devices $IntuneDevices -Action $Action -BatchSize $BatchSize
    
    Write-Host "`n🎉 Batch processing completed!" -ForegroundColor Green
    Write-Host "$Action action successfully initiated for $SuccessCount out of $($IntuneDevices.Count) devices" -ForegroundColor Cyan
    Write-Host "Note: It may take some time for the actions to complete on all devices." -ForegroundColor Yellow
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
}
finally {
    # Disconnect from Graph
    Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Yellow
    Disconnect-MgGraph
}

Write-Host "`nScript execution completed!" -ForegroundColor Green
