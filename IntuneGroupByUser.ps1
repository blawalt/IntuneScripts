# PowerShell script to get user's Intune devices and create an Entra ID device group

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
    $groupName = Read-Host "Enter the name for the new device group"
    
    if ([string]::IsNullOrWhiteSpace($groupName)) {
        $groupName = "$userEmail - Intune Devices"
        Write-Host "Using default group name: $groupName" -ForegroundColor Yellow
    }
    
    # Get the user object
    Write-Host "Retrieving user information for $userEmail..." -ForegroundColor Yellow
    $user = Get-MgUser -Filter "userPrincipalName eq '$userEmail'" -ErrorAction Stop
    
    if (-not $user) {
        Write-Error "User $userEmail not found in Azure AD"
        exit 1
    }
    
    Write-Host "Found user: $($user.DisplayName)" -ForegroundColor Green
    
    # Get Intune MDM managed devices for the user
    Write-Host "Retrieving Intune MDM managed devices..." -ForegroundColor Yellow
    $allDevices = Get-MgDeviceManagementManagedDevice -Filter "userId eq '$($user.Id)'"
    
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
        Write-Warning "No devices could be linked to Azure AD objects. Cannot create group."
        exit 1
    }
    
    # Create the device group
    Write-Host "`nCreating Entra ID device group: '$groupName'..." -ForegroundColor Yellow
    
    $groupParams = @{
        DisplayName = $groupName
        Description = "Device group for $userEmail - Created $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        GroupTypes = @()
        MailEnabled = $false
        SecurityEnabled = $true
        MailNickname = ($groupName -replace '[^a-zA-Z0-9]', '').ToLower()
    }
    
    try {
        $newGroup = New-MgGroup @groupParams
        Write-Host "✓ Group created successfully with ID: $($newGroup.Id)" -ForegroundColor Green
        
        # Add devices to the group
        Write-Host "Adding devices to the group..." -ForegroundColor Yellow
        $addedCount = 0
        
        foreach ($deviceId in $azureADDeviceIds) {
            try {
                $memberParams = @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$deviceId"
                }
                New-MgGroupMember -GroupId $newGroup.Id -BodyParameter $memberParams
                $addedCount++
                Write-Host "  ✓ Added device (Object ID: $deviceId)" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to add device $deviceId to group: $($_.Exception.Message)"
            }
        }
        
        Write-Host "SUCCESS!" -ForegroundColor Green
        Write-Host "Group Name: $($newGroup.DisplayName)" -ForegroundColor White
        Write-Host "Group ID: $($newGroup.Id)" -ForegroundColor White
        Write-Host "Devices Added: $addedCount of $($azureADDeviceIds.Count)" -ForegroundColor White
        
    } catch {
        Write-Error "Failed to create group: $($_.Exception.Message)"
    }
    
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
