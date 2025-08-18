# Detection Script for Intune Remediation
# Exits with 1 if updates are pending, 0 if no updates are found.
# Version 1.1 - Added detailed logging

# --- Logging Setup ---
$logPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\WindowsUpdates"
$logFile = "$logPath\Update_Detection.log"

# Create the log directory if it does not exist
if (-not (Test-Path -Path $logPath)) {
    try {
        New-Item -Path $logPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Warning "Could not create log directory at $logPath. Error: $_"
        # Continue without file logging if directory creation fails
    }
}

# Logging function
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] - $Message"
    
    # Write to console
    if ($Level -eq "ERROR") {
        Write-Error $logEntry
    } else {
        Write-Host $logEntry
    }

    # Write to log file if path is valid
    if (Test-Path -Path $logPath) {
        try {
            $logEntry | Add-Content -Path $logFile -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write to log file $logFile. Error: $_"
        }
    }
}
# --- End Logging Setup ---

try {
    Write-Log -Message "Detection script started."
    
    # Create a new update session
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()

    # Search for all installed software and driver updates, excluding previews
    Write-Log -Message "Searching for applicable updates..."
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and BrowseOnly=0")

    $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

    foreach ($update in $searchResult.Updates) {
        # Filter out preview updates
        if ($update.Title -notmatch "Preview") {
            $null = $updatesToInstall.Add($update)
        }
    }

    if ($updatesToInstall.Count -gt 0) {
        Write-Log -Message "Found $($updatesToInstall.Count) pending update(s)."
        # Exit with 1 to indicate that remediation is required
        Write-Log -Message "Detection finished. Remediation required. Exiting with code 1."
        exit 1
    } else {
        Write-Log -Message "No pending Windows updates found."
        # Exit with 0 to indicate the device is compliant
        Write-Log -Message "Detection finished. Device is compliant. Exiting with code 0."
        exit 0
    }
}
catch {
    # If the script fails for any reason, write the error and exit with 1
    $errorMessage = $_.Exception.Message
    Write-Log -Message "Script failed: $errorMessage" -Level 'ERROR'
    exit 1
}