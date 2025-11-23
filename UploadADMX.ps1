<##
.SYNOPSIS
    Uploads an ADMX and its corresponding ADML file to Intune.
#>

# --- CONFIGURATION ---
# RUN THIS TWICE: Once for Dell.admx (Base), Once for DellCommandUpdate.admx (Child)
$AdmxPath = "/Users/beau.lawalt/Downloads/Templates/Dell.ADMX"       
$AdmlPath = "/Users/beau.lawalt/Downloads/Templates/en-us/Dell.adml" 

# --- SCRIPT ---

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
try { Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All" -ErrorAction Stop }
catch { Write-Warning "Connect-MgGraph failed."; return }

function Get-FileBase64 {
    param ($Path)
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $Bytes = [System.IO.File]::ReadAllBytes($Path)
    return [Convert]::ToBase64String($Bytes)
}

try {
    Write-Host "Reading files..." -ForegroundColor Cyan
    $AdmxContent = Get-FileBase64 -Path $AdmxPath
    $AdmlContent = Get-FileBase64 -Path $AdmlPath
    
    # Get filenames exactly as they appear on disk
    $AdmxFileName = Split-Path $AdmxPath -Leaf
    $AdmlFileName = Split-Path $AdmlPath -Leaf

    # --- PAYLOAD 
    $Payload = @{
        content = $AdmxContent
        fileName = $AdmxFileName
        defaultLanguageCode = ""
        groupPolicyUploadedLanguageFiles = @(
            @{
                fileName = $AdmlFileName
                languageCode = "en-US"
                content = $AdmlContent
            }
        )
    }

    # Convert to JSON with depth to prevent object referencing errors
    $JsonPayload = $Payload | ConvertTo-Json -Depth 10

    # --- SEND REQUEST ---
    Write-Host "Uploading $AdmxFileName..." -ForegroundColor Cyan
    $Uri = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyUploadedDefinitionFiles"
    
    $Response = Invoke-MgGraphRequest -Method POST -Uri $Uri -Body $JsonPayload -ContentType "application/json"

    Write-Host "SUCCESS! File uploaded." -ForegroundColor Green
    Write-Host "ID: $($Response.id)"

} catch {
    Write-Host "ERROR: Upload failed." -ForegroundColor Red
    if ($_.Exception.InnerException.Message) {
        Write-Host "Details: $($_.Exception.InnerException.Message)" -ForegroundColor Yellow
    } else {
        Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
