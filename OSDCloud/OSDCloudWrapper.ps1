<#
.SYNOPSIS
A streamlined wrapper script to automate OSDCloud with specific settings for a Zero-Touch Installation (ZTI).

.DESCRIPTION
This script configures the necessary variables to deploy Windows 11 Enterprise 23H2 in a fully automated fashion.
It sets the global '$MyOSDCloud' variable, which is used by the 'Start-OSDCloud' function to customize the deployment
according to the specified requirements.
#>

# Script Information
$ScriptName = 'Invoke-OSDCloud-ZTI'
$ScriptVersion = '2025.07.09'
Write-Host "Executing [$($ScriptName)] Version [$($ScriptVersion)]" -ForegroundColor Green

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
    Restart                 = [bool]$true      # Automatically restart after the WinPE phase is complete.
    ZTI                     = [bool]$true      # Enables Zero Touch Installation, suppressing most user prompts.
    ClearDiskConfirm        = [bool]$false     # Suppresses the confirmation prompt before wiping the disk.
    OEMActivation           = [bool]$true      # Attempts to activate Windows using the firmware-embedded product key.
    WindowsUpdate           = [bool]$true      # Runs Windows Updates during the SetupComplete phase.
    WindowsUpdateDrivers    = [bool]$true      # Includes driver updates when running Windows Update.
    WindowsDefenderUpdate   = [bool]$true      # Updates Windows Defender definitions during SetupComplete.
    MSCatalogScsiDrivers    = [bool]$true      # Ensures SCSI/storage drivers are downloaded from the MS Update Catalog.
    SkipAutopilot           = [bool]$true      # Skips searching for and applying Autopilot configurations.
    SkipODT                 = [bool]$true      # Skips the Office Deployment Tool (ODT) installation.
    SkipOOBEDeploy          = [bool]$true      # Skips applying a custom OOBEDeploy.json configuration.
}

# Display the configured variables for final confirmation before starting.
Write-Host "OSDCloud will launch with the following settings:" -ForegroundColor Cyan
$Global:MyOSDCloud | Format-Table | Out-Host

# 3. Launch OSDCloud
# This command initiates the deployment. It uses the OS parameters defined above and automatically
# incorporates the settings from the $Global:MyOSDCloud variable.
Write-Host "Starting OSDCloud..." -ForegroundColor Green
Start-OSDCloud -OSVersion $OSVersion -OSBuild $OSBuild -OSEdition $OSEdition -OSLanguage $OSLanguage -OSActivation $OSActivation

# Since 'Restart = [bool]$true' is set, the main OSDCloud function will handle the reboot into the new OS.
# No further commands are needed here.
Write-Host "OSDCloud process has been initiated. The system will restart automatically upon completion." -ForegroundColor Green
