# Script Information
$ScriptName = 'Invoke-OSDCloud-ZTI'
$ScriptVersion = '2025.07.09'
# ===================================================================================
# --- START TRANSCRIPT ---
# 1. Define a persistent path for the log file (UNC network share is best).
$LogPath = "X:\"

# 2. Create the directory if it doesn't exist.
# You may need to handle permissions for this folder beforehand.
if (-not (Test-Path -Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force
}

# 3. Get a unique name for the log file (using PC Serial Number is reliable).
$PCSerial = (Get-CimInstance Win32_BIOS).SerialNumber
$LogFile = Join-Path -Path $LogPath -ChildPath "$($PCSerial)_OSDCloud.log"

# 4. Start the transcript. All subsequent commands and output will be logged.
Start-Transcript -Path $LogFile -Force
# ===================================================================================

Write-Host "Executing [$($ScriptName)] Version [$($ScriptVersion)]" -ForegroundColor Green
Write-Host "Transcript logging started. Output is being saved to: $LogFile" -ForegroundColor Cyan

# 1. Define Operating System Parameters
# These variables define the target OS and are passed to the Start-OSDCloud function.
$OSVersion = 'Windows 11'
$OSReleaseID = '23H2'
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Enterprise'
$OSLanguage = 'en-us'
$OSActivation = 'Volume'

# 2. Configure OSDCloud Global Variables
# This hashtable overrides the default OSDCloud settings.
Write-Host "Configuring OSDCloud deployment variables for a ZTI deployment..."
$Global:MyOSDCloud = [ordered]@{
    # --- Your Requested Settings ---
    Restart               = [bool]$true     # Automatically restart after the WinPE phase is complete.
    ZTI                   = [bool]$true     # Enables Zero Touch Installation, suppressing most user prompts.
    ClearDiskConfirm      = [bool]$false    # Suppresses the confirmation prompt before wiping the disk.
    OEMActivation         = [bool]$true     # Attempts to activate Windows using the firmware-embedded product key.
    WindowsUpdate         = [bool]$true     # Runs Windows Updates during the SetupComplete phase.
    WindowsUpdateDrivers  = [bool]$true     # Includes driver updates when running Windows Update.
    WindowsDefenderUpdate = [bool]$true     # Updates Windows Defender definitions during SetupComplete.
    SkipAutopilot         = [bool]$true     # Skips searching for and applying Autopilot configurations.
    SkipODT               = [bool]$true     # Skips the Office Deployment Tool (ODT) installation.
    SkipOOBEDeploy        = [bool]$true     # Skips applying a custom OOBEDeploy.json configuration.
}

# Display the configured variables for final confirmation before starting.
Write-Host "OSDCloud will launch with the following settings:" -ForegroundColor Cyan
$Global:MyOSDCloud | Format-Table | Out-Host

# 3. Launch OSDCloud
# This command initiates the deployment. It uses the OS parameters defined above and automatically
# incorporates the settings from the $Global:MyOSDCloud variable.
Write-Host "Starting OSDCloud..." -ForegroundColor Green
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

# Since 'Restart = [bool]$true' is set, the main OSDCloud function will handle the reboot into the new OS.
# No further commands are needed here.
Write-Host "OSDCloud process has been initiated. The system will restart automatically upon completion." -ForegroundColor Green

# Stop the transcript at the very end of the script
Stop-Transcript
