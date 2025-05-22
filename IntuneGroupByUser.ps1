# PowerShell script to get user's Intune devices and add them to an existing Entra ID device group

# Import required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.DeviceManagement
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.DirectoryManagement

# Connect to Microsoft Graph with required permissions
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "User.Read.All", "Device.Read.All", "Group.ReadWrite.All", "GroupMember.ReadWrite.All"

try {
    # User input parameters
    $userEmail = Read-Host "Enter user email (e.g., beans@test.onmicrosoft.com)"
    $groupID = Read-Host "Enter the object ID for existing device group"
    
    # Verify the group exists
    Write-Host "Verifying group exists..." -ForegroundColor Yellow
    try {
        $existingGroup = Get-MgGroup -GroupId $groupID -ErrorAction Stop
        Write-Host "Found group: $($existingGroup.DisplayName)" -ForegroundColor Green
    } catch {
        Write-Error "Group with ID $groupID not found or inaccessible"
        exit 1
    }
    
    # Get the user object
    Write-Host "Retrieving user information for $userEmail..." -ForegroundColor Yellow
    $user = Get-MgUser -Filter "userPrincipalName eq '$userEmail'" -ErrorAction Stop
    
    if (-not $user) {
        Write-Error "User $userEmail not found in Azure AD"
        exit 1
    }
    
    Write-Host "Found user: $($user.DisplayName)" -ForegroundColor Green
    
    # Get Intune MDM managed devices for the user by email address
    Write-Host "Retrieving Intune MDM managed devices..." -ForegroundColor Yellow
    $allDevices = Get-MgDeviceManagementManagedDevice -Filter "emailAddress eq '$userEmail'"
    
    # Filter for only Intune MDM enrolled devices
    $managedDevices = $allDevices | Where-Object { 
        $_.ManagementAgent -eq "mdm" -or 
        $_.ManagementAgent -eq "easIntuneClient" -or
        $_.ManagementAgent -eq "intuneClient"
    }
    
    if ($managedDevices.Count -eq 0) {
        Write-Host "No Intune MDM managed devices found for $userEmail" -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "`nFound $($managedDevices.Count) Intune MDM managed device(s)" -ForegroundColor Green
    
    # Get Azure AD device objects and link them
    Write-Host "Linking devices to Azure AD objects..." -ForegroundColor Yellow
    $deviceInfo = @()
    $azureADDeviceIds = @()
    
    foreach ($device in $managedDevices) {
        Write-Host "Processing: $($device.DeviceName)" -ForegroundColor Cyan
        
        # Try to find the corresponding Azure AD device
        $azureADDevice = $null
        
        if ($device.AzureADDeviceId) {
            # First try by Azure AD Device ID
            try {
                $azureADDevice = Get-MgDevice -Filter "deviceId eq '$($device.AzureADDeviceId)'" -ErrorAction SilentlyContinue
            } catch {
                Write-Warning "Could not find Azure AD device by deviceId: $($device.AzureADDeviceId)"
            }
        }
        
        # If not found by deviceId, try by display name
        if (-not $azureADDevice -and $device.DeviceName) {
            try {
                $azureADDevice = Get-MgDevice -Filter "displayName eq '$($device.DeviceName)'" -ErrorAction SilentlyContinue
            } catch {
                Write-Warning "Could not find Azure AD device by displayName: $($device.DeviceName)"
            }
        }
        
        if ($azureADDevice) {
            Write-Host "  ✓ Linked to Azure AD Object ID: $($azureADDevice.Id)" -ForegroundColor Green
            $azureADDeviceIds += $azureADDevice.Id
            
            $deviceInfo += [PSCustomObject]@{
                DeviceName = $device.DeviceName
                IntuneDeviceId = $device.Id
                AzureADObjectId = $azureADDevice.Id
                AzureADDeviceId = $device.AzureADDeviceId
                Platform = $device.OperatingSystem
                Model = "$($device.Manufacturer) $($device.Model)"
                LastSync = $device.LastSyncDateTime
                EnrollmentType = $device.DeviceEnrollmentType
                ManagementAgent = $device.ManagementAgent
            }
        } else {
            Write-Host "  ✗ Could not find Azure AD device object" -ForegroundColor Red
            $deviceInfo += [PSCustomObject]@{
                DeviceName = $device.DeviceName
                IntuneDeviceId = $device.Id
                AzureADObjectId = "NOT FOUND"
                AzureADDeviceId = $device.AzureADDeviceId
                Platform = $device.OperatingSystem
                Model = "$($device.Manufacturer) $($device.Model)"
                LastSync = $device.LastSyncDateTime
                EnrollmentType = $device.DeviceEnrollmentType
                ManagementAgent = $device.ManagementAgent
            }
        }
    }
    
    # Display summary
    Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
    Write-Host "DEVICE SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    $deviceInfo | Format-Table -AutoSize
    
    $linkedDevices = $deviceInfo | Where-Object { $_.AzureADObjectId -ne "NOT FOUND" }
    Write-Host "Devices successfully linked to Azure AD: $($linkedDevices.Count) of $($deviceInfo.Count)" -ForegroundColor Green
    
    if ($azureADDeviceIds.Count -eq 0) {
        Write-Warning "No devices could be linked to Azure AD objects. Cannot add to group."
        exit 1
    }
    
    # Add devices to the existing group
    Write-Host "Adding devices to group: $($existingGroup.DisplayName)..." -ForegroundColor Yellow
    $addedCount = 0
    $skippedCount = 0
    
    # Get current group members to avoid duplicates
    $currentMembers = Get-MgGroupMember -GroupId $groupID | Select-Object -ExpandProperty Id
    
    foreach ($deviceId in $azureADDeviceIds) {
        try {
            # Check if device is already a member
            if ($currentMembers -contains $deviceId) {
                Write-Host "  ○ Device already in group (Object ID: $deviceId)" -ForegroundColor Yellow
                $skippedCount++
                continue
            }
            
            $memberParams = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$deviceId"
            }
            New-MgGroupMember -GroupId $groupID -BodyParameter $memberParams
            $addedCount++
            Write-Host "  ✓ Added device (Object ID: $deviceId)" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to add device $deviceId to group: $($_.Exception.Message)"
        }
    }
    
    Write-Host "`nSUCCESS!" -ForegroundColor Green
    Write-Host "Group Name: $($existingGroup.DisplayName)" -ForegroundColor White
    Write-Host "Group ID: $($existingGroup.Id)" -ForegroundColor White
    Write-Host "Devices Added: $addedCount" -ForegroundColor White
    Write-Host "Devices Skipped (already members): $skippedCount" -ForegroundColor White
    Write-Host "Total Devices Found: $($azureADDeviceIds.Count)" -ForegroundColor White
    
    # Export device information to CSV
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvPath = "DeviceGroupInfo_$($userEmail.Replace('@','_').Replace('.','_'))_$timestamp.csv"
    $deviceInfo | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "`nDevice information exported to: $csvPath" -ForegroundColor Cyan
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
} finally {
    # Disconnect from Microsoft Graph
    Write-Host "`nDisconnecting from Microsoft Graph..." -ForegroundColor Yellow
    Disconnect-MgGraph
}

Write-Host "`nScript completed." -ForegroundColor Green
