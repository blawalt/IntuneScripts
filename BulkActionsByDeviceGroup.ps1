# Bulk Retire Intune Devices by Entra Group Membership
# This script gets all devices from an Entra/Azure AD group and performs bulk retire action

param(
    [Parameter(Mandatory=$true)]
    [string]$GroupName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Retire", "Wipe", "Delete", "Sync", "Restart", "FreshStart")]
    [string]$Action = "Restart",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Import required modules
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.DeviceManagement


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
    
    # Display devices that will be affected
    Write-Host "`nDevices that will be affected:" -ForegroundColor Cyan
    $IntuneDevices | ForEach-Object {
        Write-Host "  - $($_.DeviceName) ($($_.OperatingSystem)) - User: $($_.UserDisplayName)" -ForegroundColor White
    }
    
    if ($WhatIf) {
        Write-Host "`n[WHATIF] Would perform '$Action' on $($IntuneDevices.Count) devices" -ForegroundColor Magenta
        return
    }
    
    # Confirm action
    $Confirmation = Read-Host "`nAre you sure you want to perform '$Action' on these $($IntuneDevices.Count) devices? (y/N)"
    if ($Confirmation -ne 'y' -and $Confirmation -ne 'Y') {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        return
    }
    
    # Perform the bulk action
    Write-Host "`nPerforming bulk $Action action..." -ForegroundColor Yellow
    
    # Collect device IDs for bulk operation
    $DeviceIds = $IntuneDevices | ForEach-Object { '"' + $_.Id + '"' }
    $DeviceString = $DeviceIds -join ","
    
    # Define action parameters based on action type
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/executeAction"
    
    switch ($Action) {
        "Retire" {
            $JsonPayload = @{
                action = "retire"
                keepEnrollmentData = $false
                keepUserData = $true
                platform = "all"
                deviceIds = @("string")
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
                deviceIds = @("string")
                realAction = "wipe"
                actionName = "wipe"
            }
        }
        "Delete" {
            $JsonPayload = @{
                action = "delete"
                platform = "all"
                deviceIds = @("string")
                realAction = "delete"
                actionName = "delete"
            }
        }
        "Sync" {
            $JsonPayload = @{
                action = "syncDevice"
                platform = "all"
                deviceIds = @("string")
                realAction = "syncDevice"
                actionName = "syncDevice"
            }
        }
        "Restart" {
            $JsonPayload = @{
                action = "rebootNow"
                platform = "all"
                deviceIds = @("string")
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
                deviceIds = @("string")
                realAction = "freshStart"
                actionName = "freshStart"
            }
        }
    }
    
    # Convert to JSON and replace placeholder
    $Json = $JsonPayload | ConvertTo-Json
    $Json = $Json.Replace('"string"', $DeviceString)
    
    # Execute the bulk action
    try {
        Invoke-MgGraphRequest -Uri $Uri -Body $Json -Method POST -ContentType "Application/Json"
        Write-Host "`n✅ Bulk $Action action successfully initiated for $($IntuneDevices.Count) devices!" -ForegroundColor Green
        Write-Host "Note: It may take some time for the action to complete on all devices." -ForegroundColor Yellow
    }
    catch {
        Write-Error "Failed to execute bulk action: $($_.Exception.Message)"
        
        # Fallback to individual device actions
        Write-Host "Falling back to individual device actions..." -ForegroundColor Yellow
        $SuccessCount = 0
        
        foreach ($Device in $IntuneDevices) {
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
                    # Add other individual actions as needed
                }
                Write-Host "✅ $Action completed for: $($Device.DeviceName)" -ForegroundColor Green
                $SuccessCount++
            }
            catch {
                Write-Warning "❌ Failed to $Action device: $($Device.DeviceName) - $($_.Exception.Message)"
            }
        }
        
        Write-Host "`n$Action completed successfully for $SuccessCount out of $($IntuneDevices.Count) devices" -ForegroundColor Cyan
    }
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