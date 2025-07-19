##This script finds device IP given Serial
##With DNS limitations on Entra-Joined Device, 
##this can be used as a function to pull device IP for remote actions.


##Global Variables
$clientId = "<AppId>"
$tenantId = "<TenantID>"

function Get-DeviceIP{
    param(
    [Parameter(Mandatory=$true)]$SerialNumber
    )
    $scope = "https://api.securitycenter.microsoft.com/.default"
    # --- Step 1: Get access token using MSAL.PS ---
    try {
        # This prompts for interactive sign-in
        $authResult = Get-MsalToken -ClientId $clientId -TenantId $tenantId -Interactive -Scopes $scope
        $accessToken = $authResult.AccessToken
        Write-Host "Successfully acquired access token." -ForegroundColor Green
    }
    catch {
        Write-Host "Authentication failed: $_" -ForegroundColor Red
        # Exit the script if auth fails
        return 
    }

    # --- Step 2: Call the Defender API with the token ---
    # The backtick (`) before $filter and $select is required to prevent a 400 Bad Request error.
    $apiUrl = "https://api.securitycenter.microsoft.com/api/machines?`$filter=startswith(computerDnsName,'$($SerialNumber)')&`$select=lastIpAddress"
    $headers = @{
        "Authorization" = "Bearer $accessToken"
    }

    try {
        Write-Host "Querying Defender API..." -ForegroundColor Green
        $response = Invoke-RestMethod -Method Get -Uri $apiUrl -Headers $headers -ErrorAction Stop
    
        # Display the final results
        $response.value.lastIpAddress
    }
    catch {
        # This will provide detailed error information if the API call fails
        Write-Host "API call failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Full error: $_" -ForegroundColor Red
}
}

Get-DeviceIP -SerialNumber "484Y2W2"
