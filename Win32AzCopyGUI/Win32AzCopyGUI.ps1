# Intune Win32 App Uploader GUI
# This script creates a simple GUI for IT technicians to upload Win32 applications to Intune
# Prerequisites: IntuneWin32App module and Microsoft.Graph modules

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import required modules
try {
    Import-Module IntuneWin32App -ErrorAction Stop
    Import-Module Microsoft.Graph.Intune -ErrorAction SilentlyContinue
} catch {
    [System.Windows.Forms.MessageBox]::Show("Required module not found. Please ensure IntuneWin32App module is installed.`n`nInstall with: Install-Module IntuneWin32App -Force", "Module Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit
}

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Intune Win32 App Uploader"
$form.Size = New-Object System.Drawing.Size(800, 720)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Authentication status panel
$authPanel = New-Object System.Windows.Forms.Panel
$authPanel.Location = New-Object System.Drawing.Point(10, 10)
$authPanel.Size = New-Object System.Drawing.Size(765, 50)
$authPanel.BorderStyle = "FixedSingle"

$authLabel = New-Object System.Windows.Forms.Label
$authLabel.Location = New-Object System.Drawing.Point(10, 15)
$authLabel.Size = New-Object System.Drawing.Size(250, 20)
$authLabel.Text = "Authentication Status: Not Connected"
$authPanel.Controls.Add($authLabel)

$connectButton = New-Object System.Windows.Forms.Button
$connectButton.Location = New-Object System.Drawing.Point(600, 10)
$connectButton.Size = New-Object System.Drawing.Size(150, 30)
$connectButton.Text = "Connect to Graph"
$authPanel.Controls.Add($connectButton)

# Create the file path section
$filePathLabel = New-Object System.Windows.Forms.Label
$filePathLabel.Location = New-Object System.Drawing.Point(10, 80)
$filePathLabel.Size = New-Object System.Drawing.Size(150, 20)
$filePathLabel.Text = "IntuneWin File Path:"

$filePathTextBox = New-Object System.Windows.Forms.TextBox
$filePathTextBox.Location = New-Object System.Drawing.Point(160, 80)
$filePathTextBox.Size = New-Object System.Drawing.Size(520, 20)
$filePathTextBox.ReadOnly = $true

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(690, 80)
$browseButton.Size = New-Object System.Drawing.Size(80, 20)
$browseButton.Text = "Browse"

# Basic app details section
$groupBoxDetails = New-Object System.Windows.Forms.GroupBox
$groupBoxDetails.Location = New-Object System.Drawing.Point(10, 120)
$groupBoxDetails.Size = New-Object System.Drawing.Size(765, 140)
$groupBoxDetails.Text = "App Details"

$displayNameLabel = New-Object System.Windows.Forms.Label
$displayNameLabel.Location = New-Object System.Drawing.Point(10, 30)
$displayNameLabel.Size = New-Object System.Drawing.Size(150, 20)
$displayNameLabel.Text = "Display Name:"
$groupBoxDetails.Controls.Add($displayNameLabel)

$displayNameTextBox = New-Object System.Windows.Forms.TextBox
$displayNameTextBox.Location = New-Object System.Drawing.Point(160, 30)
$displayNameTextBox.Size = New-Object System.Drawing.Size(580, 20)
$groupBoxDetails.Controls.Add($displayNameTextBox)

$descriptionLabel = New-Object System.Windows.Forms.Label
$descriptionLabel.Location = New-Object System.Drawing.Point(10, 60)
$descriptionLabel.Size = New-Object System.Drawing.Size(150, 20)
$descriptionLabel.Text = "Description:"
$groupBoxDetails.Controls.Add($descriptionLabel)

$descriptionTextBox = New-Object System.Windows.Forms.TextBox
$descriptionTextBox.Location = New-Object System.Drawing.Point(160, 60)
$descriptionTextBox.Size = New-Object System.Drawing.Size(580, 20)
$groupBoxDetails.Controls.Add($descriptionTextBox)

$publisherLabel = New-Object System.Windows.Forms.Label
$publisherLabel.Location = New-Object System.Drawing.Point(10, 90)
$publisherLabel.Size = New-Object System.Drawing.Size(150, 20)
$publisherLabel.Text = "Publisher:"
$groupBoxDetails.Controls.Add($publisherLabel)

$publisherTextBox = New-Object System.Windows.Forms.TextBox
$publisherTextBox.Location = New-Object System.Drawing.Point(160, 90)
$publisherTextBox.Size = New-Object System.Drawing.Size(580, 20)
$groupBoxDetails.Controls.Add($publisherTextBox)

# Installation options section
$groupBoxInstall = New-Object System.Windows.Forms.GroupBox
$groupBoxInstall.Location = New-Object System.Drawing.Point(10, 270)
$groupBoxInstall.Size = New-Object System.Drawing.Size(765, 130)
$groupBoxInstall.Text = "Installation Options"

$installExperienceLabel = New-Object System.Windows.Forms.Label
$installExperienceLabel.Location = New-Object System.Drawing.Point(10, 30)
$installExperienceLabel.Size = New-Object System.Drawing.Size(150, 20)
$installExperienceLabel.Text = "Install Experience:"
$groupBoxInstall.Controls.Add($installExperienceLabel)

$installExperienceComboBox = New-Object System.Windows.Forms.ComboBox
$installExperienceComboBox.Location = New-Object System.Drawing.Point(160, 30)
$installExperienceComboBox.Size = New-Object System.Drawing.Size(200, 20)
$installExperienceComboBox.DropDownStyle = "DropDownList"
[void]$installExperienceComboBox.Items.Add("system")
[void]$installExperienceComboBox.Items.Add("user")
$installExperienceComboBox.SelectedIndex = 0
$groupBoxInstall.Controls.Add($installExperienceComboBox)

$restartLabel = New-Object System.Windows.Forms.Label
$restartLabel.Location = New-Object System.Drawing.Point(10, 60)
$restartLabel.Size = New-Object System.Drawing.Size(150, 20)
$restartLabel.Text = "Restart Behavior:"
$groupBoxInstall.Controls.Add($restartLabel)

$restartComboBox = New-Object System.Windows.Forms.ComboBox
$restartComboBox.Location = New-Object System.Drawing.Point(160, 60)
$restartComboBox.Size = New-Object System.Drawing.Size(200, 20)
$restartComboBox.DropDownStyle = "DropDownList"
[void]$restartComboBox.Items.Add("suppress")
[void]$restartComboBox.Items.Add("allow")
[void]$restartComboBox.Items.Add("basedOnReturnCode")
[void]$restartComboBox.Items.Add("force")
$restartComboBox.SelectedIndex = 0
$groupBoxInstall.Controls.Add($restartComboBox)

$cmdLineLabel = New-Object System.Windows.Forms.Label
$cmdLineLabel.Location = New-Object System.Drawing.Point(10, 90)
$cmdLineLabel.Size = New-Object System.Drawing.Size(150, 20)
$cmdLineLabel.Text = "Install Command Line:"
$groupBoxInstall.Controls.Add($cmdLineLabel)

$cmdLineTextBox = New-Object System.Windows.Forms.TextBox
$cmdLineTextBox.Location = New-Object System.Drawing.Point(160, 90)
$cmdLineTextBox.Size = New-Object System.Drawing.Size(580, 20)
$groupBoxInstall.Controls.Add($cmdLineTextBox)

$uninstallCmdLineLabel = New-Object System.Windows.Forms.Label
$uninstallCmdLineLabel.Location = New-Object System.Drawing.Point(380, 30)
$uninstallCmdLineLabel.Size = New-Object System.Drawing.Size(150, 20)
$uninstallCmdLineLabel.Text = "Uninstall Command Line:"
$groupBoxInstall.Controls.Add($uninstallCmdLineLabel)

$uninstallCmdLineTextBox = New-Object System.Windows.Forms.TextBox
$uninstallCmdLineTextBox.Location = New-Object System.Drawing.Point(535, 30)
$uninstallCmdLineTextBox.Size = New-Object System.Drawing.Size(205, 20)
$groupBoxInstall.Controls.Add($uninstallCmdLineTextBox)

# Detection Rule section
$groupBoxDetection = New-Object System.Windows.Forms.GroupBox
$groupBoxDetection.Location = New-Object System.Drawing.Point(10, 410)
$groupBoxDetection.Size = New-Object System.Drawing.Size(765, 130)
$groupBoxDetection.Text = "Detection Rule"

$detectionPathLabel = New-Object System.Windows.Forms.Label
$detectionPathLabel.Location = New-Object System.Drawing.Point(10, 30)
$detectionPathLabel.Size = New-Object System.Drawing.Size(150, 20)
$detectionPathLabel.Text = "Path:"
$groupBoxDetection.Controls.Add($detectionPathLabel)

$detectionPathTextBox = New-Object System.Windows.Forms.TextBox
$detectionPathTextBox.Location = New-Object System.Drawing.Point(160, 30)
$detectionPathTextBox.Size = New-Object System.Drawing.Size(470, 20)
$detectionPathTextBox.Text = "C:\Program Files\"
$groupBoxDetection.Controls.Add($detectionPathTextBox)

$browseFolderButton = New-Object System.Windows.Forms.Button
$browseFolderButton.Location = New-Object System.Drawing.Point(640, 30)
$browseFolderButton.Size = New-Object System.Drawing.Size(100, 20)
$browseFolderButton.Text = "Browse Folder"
$groupBoxDetection.Controls.Add($browseFolderButton)

$fileOrFolderLabel = New-Object System.Windows.Forms.Label
$fileOrFolderLabel.Location = New-Object System.Drawing.Point(10, 60)
$fileOrFolderLabel.Size = New-Object System.Drawing.Size(150, 20)
$fileOrFolderLabel.Text = "File or Folder Name:"
$groupBoxDetection.Controls.Add($fileOrFolderLabel)

$fileOrFolderTextBox = New-Object System.Windows.Forms.TextBox
$fileOrFolderTextBox.Location = New-Object System.Drawing.Point(160, 60)
$fileOrFolderTextBox.Size = New-Object System.Drawing.Size(580, 20)
$groupBoxDetection.Controls.Add($fileOrFolderTextBox)

$detectionTypeLabel = New-Object System.Windows.Forms.Label
$detectionTypeLabel.Location = New-Object System.Drawing.Point(10, 90)
$detectionTypeLabel.Size = New-Object System.Drawing.Size(150, 20)
$detectionTypeLabel.Text = "Detection Type:"
$groupBoxDetection.Controls.Add($detectionTypeLabel)

$detectionTypeComboBox = New-Object System.Windows.Forms.ComboBox
$detectionTypeComboBox.Location = New-Object System.Drawing.Point(160, 90)
$detectionTypeComboBox.Size = New-Object System.Drawing.Size(200, 20)
$detectionTypeComboBox.DropDownStyle = "DropDownList"
[void]$detectionTypeComboBox.Items.Add("exists")
[void]$detectionTypeComboBox.Items.Add("doesNotExist")
$detectionTypeComboBox.SelectedIndex = 0
$groupBoxDetection.Controls.Add($detectionTypeComboBox)

# Requirements section
$groupBoxRequirements = New-Object System.Windows.Forms.GroupBox
$groupBoxRequirements.Location = New-Object System.Drawing.Point(10, 550)
$groupBoxRequirements.Size = New-Object System.Drawing.Size(765, 80)
$groupBoxRequirements.Text = "Requirements"

$architectureLabel = New-Object System.Windows.Forms.Label
$architectureLabel.Location = New-Object System.Drawing.Point(10, 30)
$architectureLabel.Size = New-Object System.Drawing.Size(150, 20)
$architectureLabel.Text = "Architecture:"
$groupBoxRequirements.Controls.Add($architectureLabel)

$architectureComboBox = New-Object System.Windows.Forms.ComboBox
$architectureComboBox.Location = New-Object System.Drawing.Point(160, 30)
$architectureComboBox.Size = New-Object System.Drawing.Size(200, 20)
$architectureComboBox.DropDownStyle = "DropDownList"
[void]$architectureComboBox.Items.Add("All")
[void]$architectureComboBox.Items.Add("x64")
[void]$architectureComboBox.Items.Add("x86")
$architectureComboBox.SelectedIndex = 1
$groupBoxRequirements.Controls.Add($architectureComboBox)

$minWindowsLabel = New-Object System.Windows.Forms.Label
$minWindowsLabel.Location = New-Object System.Drawing.Point(380, 30)
$minWindowsLabel.Size = New-Object System.Drawing.Size(150, 20)
$minWindowsLabel.Text = "Min Windows Version:"
$groupBoxRequirements.Controls.Add($minWindowsLabel)

$minWindowsComboBox = New-Object System.Windows.Forms.ComboBox
$minWindowsComboBox.Location = New-Object System.Drawing.Point(535, 30)
$minWindowsComboBox.Size = New-Object System.Drawing.Size(205, 20)
$minWindowsComboBox.DropDownStyle = "DropDownList"
[void]$minWindowsComboBox.Items.Add("W10_20H2")
[void]$minWindowsComboBox.Items.Add("W10_21H1")
[void]$minWindowsComboBox.Items.Add("W10_21H2")
[void]$minWindowsComboBox.Items.Add("W10_22H2")
[void]$minWindowsComboBox.Items.Add("W11_21H2")
[void]$minWindowsComboBox.Items.Add("W11_22H2")
$minWindowsComboBox.SelectedIndex = 0
$groupBoxRequirements.Controls.Add($minWindowsComboBox)

# Create and upload button
$uploadButton = New-Object System.Windows.Forms.Button
$uploadButton.Location = New-Object System.Drawing.Point(10, 640)
$uploadButton.Size = New-Object System.Drawing.Size(765, 30)
$uploadButton.Text = "Create and Upload App"
$uploadButton.Enabled = $false

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 680)
$statusLabel.Size = New-Object System.Drawing.Size(765, 20)
$statusLabel.Text = "Ready"

# Add Browse button click handler
$browseButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "IntuneWin Files (*.intunewin)|*.intunewin"
    $openFileDialog.Title = "Select an IntuneWin File"
    
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $filePathTextBox.Text = $openFileDialog.FileName
        
        # Auto-populate display name from filename
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($openFileDialog.FileName)
        $displayNameTextBox.Text = $fileName
        $descriptionTextBox.Text = "$fileName application"
        $publisherTextBox.Text = ""
    }
})

# Add Browse Folder button click handler
$browseFolderButton.Add_Click({
    $folderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowserDialog.Description = "Select detection path folder"
    
    if ($folderBrowserDialog.ShowDialog() -eq "OK") {
        $detectionPathTextBox.Text = $folderBrowserDialog.SelectedPath
    }
})

# Connect button click handler
$connectButton.Add_Click({
    try {
	$TenantID = "ENTER TENANT ID HERE"
        Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All" -TenantId $TenantId -NoWelcome
        
        # Apply the workaround for authentication
        # Override internal functions with patched versions
        if (-not (Get-Alias -Name 'Invoke-AzureADGraphRequest' -ErrorAction SilentlyContinue)) {
            # Get the definitions of the patched functions
            $functionText = @'
function Global:Invoke-AzureADGraphRequest2 {
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Resource,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("GET")]
        [string]$Method
    )
    try {
        # Construct full URI
        $GraphURI = "https://graph.microsoft.com/v1.0/$($Resource)"
        Write-Verbose -Message "$($Method) $($GraphURI)"

        # Call Graph API and get JSON response
        switch ($Method) {
            "GET" {
                $GraphResponse = Invoke-MgGraphRequest -Uri $GraphURI -Method $Method -ErrorAction "Stop" -Verbose:$false
            }
        }

        return $GraphResponse
    }
    catch [System.Exception] {
        # Construct stream reader for reading the response body from API call depending on PSEdition value
        switch ($PSEdition) {
            "Desktop" {
                # Construct stream reader for reading the response body from API call
                $ResponseBody = Get-ErrorResponseBody -Exception $_.Exception
            }
            "Core" {
                $ResponseBody = $_.ErrorDetails.Message
            }
        }

        # Handle response output and error message
        Write-Output -InputObject "Response content:`n$ResponseBody"
        Write-Warning -Message "Request to $($GraphURI) failed with HTTP Status $($_.Exception.Response.StatusCode) and description: $($_.Exception.Response.StatusDescription)"
    }
}

function Global:Invoke-IntuneGraphRequest2 {
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Beta", "v1.0")]
        [string]$APIVersion,

        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Route = "deviceAppManagement",

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Resource,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("GET", "POST", "PATCH", "DELETE")]
        [string]$Method,

        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.Object]$Body,

        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ContentType = "application/json; charset=utf-8"
    )
    try {
        # Construct full URI
        $GraphURI = "https://graph.microsoft.com/$($APIVersion)/$($Route)/$($Resource)"
        Write-Verbose -Message "$($Method) $($GraphURI)"

        # Call Graph API and get JSON response
        switch ($Method) {
            "GET" {
                $GraphResponse = Invoke-MgGraphRequest -Uri $GraphURI -Method $Method -ErrorAction Stop -Verbose:$false
            }
            "POST" {
                $GraphResponse = Invoke-MgGraphRequest -Uri $GraphURI -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop -Verbose:$false
            }
            "PATCH" {
                $GraphResponse = Invoke-MgGraphRequest -Uri $GraphURI -Method $Method -Body $Body -ContentType $ContentType -ErrorAction Stop -Verbose:$false
            }
            "DELETE" {
                $GraphResponse = Invoke-MgGraphRequest -Uri $GraphURI -Method $Method -ErrorAction Stop -Verbose:$false
            }
        }

        return $GraphResponse
    }
    catch [System.Exception] {
        # Capture current error
        $ExceptionItem = $PSItem

        # Construct response error custom object for cross platform support
        $ResponseBody = [PSCustomObject]@{
            "ErrorMessage" = [string]::Empty
            "ErrorCode" = [string]::Empty
        }

        # Read response error details differently depending PSVersion
        switch ($PSVersionTable.PSVersion.Major) {
            "5" {
                # Read the response stream
                $StreamReader = New-Object -TypeName "System.IO.StreamReader" -ArgumentList @($ExceptionItem.Exception.Response.GetResponseStream())
                $StreamReader.BaseStream.Position = 0
                $StreamReader.DiscardBufferedData()
                $ResponseReader = ($StreamReader.ReadToEnd() | ConvertFrom-Json)

                # Set response error details
                $ResponseBody.ErrorMessage = $ResponseReader.error.message
                $ResponseBody.ErrorCode = $ResponseReader.error.code
            }
            default {
                $ErrorDetails = $ExceptionItem.ErrorDetails.Message | ConvertFrom-Json

                # Set response error details
                $ResponseBody.ErrorMessage = $ErrorDetails.error.message
                $ResponseBody.ErrorCode = $ErrorDetails.error.code
            }
        }

        # Convert status code to integer for output
        $HttpStatusCodeInteger = ([int][System.Net.HttpStatusCode]$ExceptionItem.Exception.Response.StatusCode)

        switch ($Method) {
            "GET" {
                # Output warning message that the request failed with error message description from response stream
                Write-Warning -Message "Graph request failed with status code '$($HttpStatusCodeInteger) ($($ExceptionItem.Exception.Response.StatusCode))'. Error details: $($ResponseBody.ErrorCode) - $($ResponseBody.ErrorMessage)"
            }
            default {
                # Construct new custom error record
                $SystemException = New-Object -TypeName "System.Management.Automation.RuntimeException" -ArgumentList ("{0}: {1}" -f $ResponseBody.ErrorCode, $ResponseBody.ErrorMessage)
                $ErrorRecord = New-Object -TypeName "System.Management.Automation.ErrorRecord" -ArgumentList @($SystemException, $ErrorID, [System.Management.Automation.ErrorCategory]::NotImplemented, [string]::Empty)

                # Throw a terminating custom error record
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }
        }
    }
}
'@
            
            # Execute the function definitions
            Invoke-Expression $functionText
            
            # Create aliases
            New-Alias -Name 'Invoke-AzureADGraphRequest' -Value 'Invoke-AzureADGraphRequest2' -Scope Global -Force
            New-Alias -Name 'Invoke-IntuneGraphRequest' -Value 'Invoke-IntuneGraphRequest2' -Scope Global -Force
            
            # Set the global variables needed for authentication
            $context = Get-MgContext
            $token = $context.AccessToken
            
            $Global:AccessToken = @{ 
                ExpiresOn = [System.DateTimeOffset]::Now.AddHours(10)
                AccessToken = $token
            }
            
            $Global:AuthenticationHeader = @{ 
                Authorization = "Bearer $token"
                ExpiresOn = [System.DateTime]::Now.AddHours(10)
            }
        }
        
        # Update UI
        $authLabel.Text = "Authentication Status: Connected"
        $connectButton.Text = "Connected"
        $connectButton.Enabled = $false
        $uploadButton.Enabled = $true
        $statusLabel.Text = "Connected to Microsoft Graph. Ready to upload."
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to connect to Microsoft Graph: $_", "Connection Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Upload button click handler
$uploadButton.Add_Click({
    # Validate inputs
    if (-not $filePathTextBox.Text -or -not (Test-Path $filePathTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid .intunewin file.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if ([string]::IsNullOrWhiteSpace($displayNameTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Display Name is required.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if ([string]::IsNullOrWhiteSpace($cmdLineTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Install Command Line is required.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if ([string]::IsNullOrWhiteSpace($uninstallCmdLineTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Uninstall Command Line is required.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if ([string]::IsNullOrWhiteSpace($detectionPathTextBox.Text) -or [string]::IsNullOrWhiteSpace($fileOrFolderTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Detection Path and File/Folder Name are required.", "Validation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    # Gather all data from GUI controls
    $script:uploadParams = @{
        FilePath = $filePathTextBox.Text
        DisplayName = $displayNameTextBox.Text
        Description = $descriptionTextBox.Text
        Publisher = $publisherTextBox.Text
        InstallExperience = $installExperienceComboBox.SelectedItem.ToString()
        RestartBehavior = $restartComboBox.SelectedItem.ToString()
        InstallCommandLine = $cmdLineTextBox.Text
        UninstallCommandLine = $uninstallCmdLineTextBox.Text
        DetectionPath = $detectionPathTextBox.Text
        FileOrFolder = $fileOrFolderTextBox.Text
        DetectionType = $detectionTypeComboBox.SelectedItem.ToString()
        Architecture = $architectureComboBox.SelectedItem.ToString()
        MinimumSupportedWindowsRelease = $minWindowsComboBox.SelectedItem.ToString()
        Check32BitOn64System = $false
    }

    # Inform user GUI will close and ask for confirmation
    $userResponse = [System.Windows.Forms.MessageBox]::Show("The GUI will now close and the upload process will begin in the console. You will be notified with a pop-up upon completion or error. Continue?", "Process Starting", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Information)

    if ($userResponse -eq [System.Windows.Forms.DialogResult]::Yes) {
        $script:shouldStartUpload = $true
        $form.Close() # Close the form, script execution will continue after $form.ShowDialog()
    } else {
        $script:shouldStartUpload = $false
        # User chose not to proceed, $uploadButton remains enabled, status label could be updated if needed.
    }
})

# Add controls to the form
$form.Controls.Add($authPanel)
$form.Controls.Add($filePathLabel)
$form.Controls.Add($filePathTextBox)
$form.Controls.Add($browseButton)
$form.Controls.Add($groupBoxDetails)
$form.Controls.Add($groupBoxInstall)
$form.Controls.Add($groupBoxDetection)
$form.Controls.Add($groupBoxRequirements)
$form.Controls.Add($uploadButton)
$form.Controls.Add($statusLabel)


# Initialize flags for post-GUI processing
$script:shouldStartUpload = $false
$script:uploadParams = $null

# Show the form - This is a blocking call.
# The script will pause here until the form is closed.
Write-Host "Launching Intune Win32 App Uploader GUI..."
[void]$form.ShowDialog()

# Dispose of the form resources once it's closed
$form.Dispose()

# --- Post-GUI Processing ---
# This code runs after the form has been closed

if ($script:shouldStartUpload -eq $true -and $script:uploadParams -ne $null) {
    Write-Host "GUI closed. Initiating Intune Win32 app upload process..."
    Write-Host "Parameters:"
    $script:uploadParams.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key): $($_.Value)" }
    Write-Host "--------------------------------------------------------"

    try {
        Write-Host "Creating detection rule..."
        $DetectionRule = New-IntuneWin32AppDetectionRuleFile -Existence `
            -Path $script:uploadParams.DetectionPath `
            -FileOrFolder $script:uploadParams.FileOrFolder `
            -DetectionType $script:uploadParams.DetectionType `
            -Check32BitOn64System $script:uploadParams.Check32BitOn64System

        Write-Host "Detection rule created."

        Write-Host "Creating requirement rule..."
        $RequirementRule = New-IntuneWin32AppRequirementRule `
            -Architecture $script:uploadParams.Architecture `
            -MinimumSupportedWindowsRelease $script:uploadParams.MinimumSupportedWindowsRelease

        Write-Host "Requirement rule created."

        Write-Host "Uploading application to Intune... This may take several minutes."
        # Ensure the Graph connection is still valid. The connection logic in your script
        # sets global variables that Add-IntuneWin32App should use.
        $Win32App = Add-IntuneWin32App `
            -FilePath $script:uploadParams.FilePath `
            -DisplayName $script:uploadParams.DisplayName `
            -Description $script:uploadParams.Description `
            -Publisher $script:uploadParams.Publisher `
            -InstallExperience $script:uploadParams.InstallExperience `
            -RestartBehavior $script:uploadParams.RestartBehavior `
            -DetectionRule $DetectionRule `
            -RequirementRule $RequirementRule `
            -InstallCommandLine $script:uploadParams.InstallCommandLine `
            -UninstallCommandLine $script:uploadParams.UninstallCommandLine `
            -Verbose `
            -UseAzCopy

        Write-Host "Upload complete."
        [System.Windows.Forms.MessageBox]::Show("Application '$($script:uploadParams.DisplayName)' has been successfully uploaded to Intune. ID: $($Win32App.id)", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        Write-Host "Application '$($script:uploadParams.DisplayName)' uploaded successfully. ID: $($Win32App.id)"
    }
    catch {
        $errorMessage = "Error during upload process: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            $errorMessage += " `nInner Exception: $($_.Exception.InnerException.Message)"
        }
        Write-Error $errorMessage
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Upload Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
} else {
    Write-Host "GUI closed or upload cancelled by user. No upload process initiated."
}

Write-Host "Script finished."
