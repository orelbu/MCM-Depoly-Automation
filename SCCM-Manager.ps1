#Requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Global:AppConfigsDir = Join-Path $PSScriptRoot "AppConfigs"
$Global:EnvConfigPath = Join-Path $PSScriptRoot "Env-Config.json"

if (-not (Test-Path $Global:AppConfigsDir)) { New-Item -ItemType Directory -Path $Global:AppConfigsDir -Force | Out-Null }

$BgColor      = [System.Drawing.Color]::FromArgb(243, 242, 241) 
$White        = [System.Drawing.Color]::White
$PrimaryBlue  = [System.Drawing.Color]::FromArgb(0, 120, 212)   
$DangerRed    = [System.Drawing.Color]::FromArgb(209, 52, 56)   
$TextColor    = [System.Drawing.Color]::FromArgb(37, 36, 35)    
$InfoBgColor  = [System.Drawing.Color]::FromArgb(204, 232, 255) 
$InfoTextColor= [System.Drawing.Color]::FromArgb(0, 74, 131)    
$DefaultFont  = New-Object System.Drawing.Font("Segoe UI", 9)
$HeaderFont   = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
$LabelFont    = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

function Set-ButtonStyle($Btn, [bool]$IsDanger = $false) {
    $Btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Btn.FlatAppearance.BorderSize = 0
    $Btn.Font = $DefaultFont
    $Btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($IsDanger) {
        $Btn.BackColor = $DangerRed
        $Btn.ForeColor = $White
    } else {
        $Btn.BackColor = $PrimaryBlue
        $Btn.ForeColor = $White
    }
}

function Set-FormStyle($Form) {
    $Form.BackColor = $BgColor
    $Form.ForeColor = $TextColor
    $Form.Font = $DefaultFont
}

function Get-EnvStatus {
    if (Test-Path $Global:EnvConfigPath) { return $true }
    return $false
}

function Load-AppsList {
    $ListBoxApps.Items.Clear()
    $Files = Get-ChildItem -Path $Global:AppConfigsDir -Filter "*.json"
    foreach ($File in $Files) {
        $AppConfig = Get-Content $File.FullName -Raw | ConvertFrom-Json
        [void]$ListBoxApps.Items.Add($AppConfig.AppName)
    }
}

function Show-EnvForm {
    $EnvForm = New-Object System.Windows.Forms.Form
    $EnvForm.Text = "Configuration Manager - Global Environment Setup"
    $EnvForm.Size = New-Object System.Drawing.Size(520, 360)
    $EnvForm.StartPosition = "CenterParent"
    $EnvForm.FormBorderStyle = "FixedDialog"
    Set-FormStyle $EnvForm

    $EnvKeys = @("SiteCode", "SmtpServer", "EmailFrom", "EmailTo", "SccmModulePath", "LogDirectory")
    $EnvDefaults = @{
        "SiteCode" = "XYZ"
        "SmtpServer" = "smtp.domain.com"
        "EmailFrom" = "sccm@domain.com"
        "EmailTo" = "admin@domain.com"
        "SccmModulePath" = "C:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
        "LogDirectory" = "C:\Temp\SCCM_Logs"
    }

    $ExistingConfig = $null
    if (Get-EnvStatus) { $ExistingConfig = Get-Content $Global:EnvConfigPath -Raw | ConvertFrom-Json }

    [int]$YOffset = 30
    $TextBoxes = @{}

    foreach ($Key in $EnvKeys) {
        $Label = New-Object System.Windows.Forms.Label
        $Label.Text = "$Key`:"
        $Label.Location = New-Object System.Drawing.Point(20, $YOffset)
        $Label.Size = New-Object System.Drawing.Size(120, 20)
        $EnvForm.Controls.Add($Label)

        $TextBox = New-Object System.Windows.Forms.TextBox
        $TextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $TextBox.BackColor = $White
        $TextBox.ForeColor = $TextColor
        
        $Val = $EnvDefaults[$Key]
        if ($null -ne $ExistingConfig) {
            $Extracted = $ExistingConfig.$Key
            if ($null -ne $Extracted -and $Extracted -ne "") {
                $Val = $Extracted
            }
        }
        $TextBox.Text = [string]$Val
        $TextBox.Location = New-Object System.Drawing.Point(150, ($YOffset - 2))
        $TextBox.Size = New-Object System.Drawing.Size(320, 25)
        
        $EnvForm.Controls.Add($TextBox)
        $TextBoxes[$Key] = $TextBox
        
        $YOffset += 35
    }

    $SaveBtn = New-Object System.Windows.Forms.Button
    $SaveBtn.Text = "Save Environment Config"
    $SaveBtn.Location = New-Object System.Drawing.Point(150, ($YOffset + 10))
    $SaveBtn.Size = New-Object System.Drawing.Size(200, 32)
    Set-ButtonStyle $SaveBtn
    $SaveBtn.Add_Click({
        $ConfigData = [ordered]@{}
        foreach ($Key in $EnvKeys) { $ConfigData[$Key] = $TextBoxes[$Key].Text }
        $ConfigData | ConvertTo-Json -Depth 2 | Out-File $Global:EnvConfigPath -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Environment saved successfully.", "Success", 0, 64)
        $EnvForm.Close()
    })
    $EnvForm.Controls.Add($SaveBtn)
    [void]$EnvForm.ShowDialog()
}

function Show-AppForm([string]$EditAppName = "") {
    if (-not (Get-EnvStatus)) {
        [System.Windows.Forms.MessageBox]::Show("Please configure the Global Environment first.", "Error", 0, 16)
        return
    }

    $AppForm = New-Object System.Windows.Forms.Form
    $AppForm.Text = if ($EditAppName) { "Edit Application: $EditAppName" } else { "Add New Application" }
    $AppForm.Size = New-Object System.Drawing.Size(520, 380)
    $AppForm.StartPosition = "CenterParent"
    $AppForm.FormBorderStyle = "FixedDialog"
    Set-FormStyle $AppForm

    $AppKeys = @("AppName", "MsiNetworkPath", "CollectionName", "DpGroupName", "FolderToWatch", "RunAsUser")
    $AppDefaults = @{
        "AppName" = ""
        "MsiNetworkPath" = "\\Server\Share\App"
        "CollectionName" = "Target Collection ID"
        "DpGroupName" = "All DPs"
        "FolderToWatch" = "\\Server\Share\App"
        "RunAsUser" = "DOMAIN\User"
    }

    $ExistingData = $null
    if ($EditAppName) {
        $SafeName = $EditAppName -replace '[\\/:\*\?"<>\| ]', ''
        $AppJsonPath = Join-Path $Global:AppConfigsDir "$SafeName.json"
        if (Test-Path $AppJsonPath) {
            $ExistingData = Get-Content $AppJsonPath -Raw | ConvertFrom-Json
        }
    }

    [int]$YOffset = 30
    $TextBoxes = @{}

    foreach ($Key in $AppKeys) {
        $Label = New-Object System.Windows.Forms.Label
        $Label.Text = "$Key`:"
        $Label.Location = New-Object System.Drawing.Point(20, $YOffset)
        $Label.Size = New-Object System.Drawing.Size(120, 20)
        $AppForm.Controls.Add($Label)

        $TextBox = New-Object System.Windows.Forms.TextBox
        $TextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $TextBox.BackColor = $White
        $TextBox.ForeColor = $TextColor
        
        $Val = $AppDefaults[$Key]
        if ($null -ne $ExistingData) {
            $Extracted = $ExistingData.$Key
            if ($null -ne $Extracted -and $Extracted -ne "") {
                $Val = $Extracted
            }
        }
        $TextBox.Text = [string]$Val
        
        if ($Key -eq "AppName" -and $EditAppName) { 
            $TextBox.Enabled = $false 
            $TextBox.BackColor = [System.Drawing.Color]::FromArgb(235, 235, 235) 
        }
        
        $TextBox.Location = New-Object System.Drawing.Point(150, ($YOffset - 2))
        $TextBox.Size = New-Object System.Drawing.Size(320, 25)
        $AppForm.Controls.Add($TextBox)
        $TextBoxes[$Key] = $TextBox
        
        $YOffset += 35
    }

    $LblPass = New-Object System.Windows.Forms.Label
    $LblPass.Text = "Task Password:"
    $LblPass.Location = New-Object System.Drawing.Point(20, $YOffset)
    $LblPass.Size = New-Object System.Drawing.Size(120, 20)
    $AppForm.Controls.Add($LblPass)

    $TxtPass = New-Object System.Windows.Forms.TextBox
    $TxtPass.PasswordChar = '*'
    $TxtPass.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TxtPass.BackColor = $White
    $TxtPass.ForeColor = $TextColor
    $TxtPass.Location = New-Object System.Drawing.Point(150, ($YOffset - 2))
    $TxtPass.Size = New-Object System.Drawing.Size(320, 25)
    $AppForm.Controls.Add($TxtPass)
    $YOffset += 45

    $SaveBtn = New-Object System.Windows.Forms.Button
    $SaveBtn.Text = "Save & Register Task"
    $SaveBtn.Location = New-Object System.Drawing.Point(150, $YOffset)
    $SaveBtn.Size = New-Object System.Drawing.Size(200, 32)
    Set-ButtonStyle $SaveBtn
    $SaveBtn.Add_Click({
        if ([string]::IsNullOrWhiteSpace($TxtPass.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Password is required to register the Scheduled Task.", "Warning", 0, 48)
            return
        }

        $AppData = [ordered]@{}
        foreach ($Key in $AppKeys) { $AppData[$Key] = $TextBoxes[$Key].Text }
        
        $SafeName = $AppData.AppName -replace '[\\/:\*\?"<>\| ]', ''
        $AppJsonPath = Join-Path $Global:AppConfigsDir "$SafeName.json"
        
        $AppData | ConvertTo-Json -Depth 2 | Out-File $AppJsonPath -Encoding UTF8
        
        $TaskName = "SCCM_Watcher_$SafeName"
        $WatcherScript = Join-Path $PSScriptRoot "Start-AppWatcher.ps1"
        
        try {
            $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$WatcherScript`" -AppConfigPath `"$AppJsonPath`"" -WorkingDirectory $PSScriptRoot
            $Trigger = New-ScheduledTaskTrigger -AtStartup
            $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 0)
            
            Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -User $AppData.RunAsUser -Password $TxtPass.Text -RunLevel Highest -Settings $Settings -Description "SCCM Watcher for $($AppData.AppName)" -Force | Out-Null
            Start-ScheduledTask -TaskName $TaskName | Out-Null
            
            [System.Windows.Forms.MessageBox]::Show("Application saved and Task registered successfully.", "Success", 0, 64)
            $AppForm.Close()
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to register task. Check username/password. Error: $($_.Exception.Message)", "Error", 0, 16)
        }
    })
    $AppForm.Controls.Add($SaveBtn)
    [void]$AppForm.ShowDialog()
}

$MainForm = New-Object System.Windows.Forms.Form
$MainForm.Text = "MCM Deploy Automation - Bussani Edition"
$MainForm.Size = New-Object System.Drawing.Size(640, 510)
$MainForm.StartPosition = "CenterScreen"
$MainForm.FormBorderStyle = "FixedDialog"
$MainForm.MaximizeBox = $false
Set-FormStyle $MainForm

$HeaderPanel = New-Object System.Windows.Forms.Panel
$HeaderPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 32, 80) 
$HeaderPanel.Size = New-Object System.Drawing.Size(640, 60)
$HeaderPanel.Location = New-Object System.Drawing.Point(0, 0)
$MainForm.Controls.Add($HeaderPanel)

$HeaderLabel = New-Object System.Windows.Forms.Label
$HeaderLabel.Text = "Deployment Automation Console"
$HeaderLabel.ForeColor = $White
$HeaderLabel.Font = $HeaderFont
$HeaderLabel.AutoSize = $true
$HeaderLabel.Location = New-Object System.Drawing.Point(20, 20)
$HeaderPanel.Controls.Add($HeaderLabel)

$LblEnvStatus = New-Object System.Windows.Forms.Label
$LblEnvStatus.Location = New-Object System.Drawing.Point(20, 80)
$LblEnvStatus.Size = New-Object System.Drawing.Size(300, 25)
$LblEnvStatus.Font = $LabelFont
$MainForm.Controls.Add($LblEnvStatus)

$BtnEnvConfig = New-Object System.Windows.Forms.Button
$BtnEnvConfig.Text = "Global Settings"
$BtnEnvConfig.Location = New-Object System.Drawing.Point(440, 80)
$BtnEnvConfig.Size = New-Object System.Drawing.Size(160, 30)
Set-ButtonStyle $BtnEnvConfig
$BtnEnvConfig.Add_Click({ Show-EnvForm; Update-UI })
$MainForm.Controls.Add($BtnEnvConfig)

$Divider = New-Object System.Windows.Forms.Label
$Divider.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$Divider.Size = New-Object System.Drawing.Size(580, 2)
$Divider.Location = New-Object System.Drawing.Point(20, 125)
$MainForm.Controls.Add($Divider)

$LblApps = New-Object System.Windows.Forms.Label
$LblApps.Text = "Configured Applications:"
$LblApps.Location = New-Object System.Drawing.Point(20, 140)
$LblApps.Size = New-Object System.Drawing.Size(200, 20)
$MainForm.Controls.Add($LblApps)

$ListBoxApps = New-Object System.Windows.Forms.ListBox
$ListBoxApps.Location = New-Object System.Drawing.Point(20, 160)
$ListBoxApps.Size = New-Object System.Drawing.Size(400, 240)
$ListBoxApps.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$ListBoxApps.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$MainForm.Controls.Add($ListBoxApps)

$BtnAddApp = New-Object System.Windows.Forms.Button
$BtnAddApp.Text = "Add Application"
$BtnAddApp.Location = New-Object System.Drawing.Point(440, 160)
$BtnAddApp.Size = New-Object System.Drawing.Size(160, 32)
Set-ButtonStyle $BtnAddApp
$BtnAddApp.Add_Click({ Show-AppForm; Update-UI })
$MainForm.Controls.Add($BtnAddApp)

$BtnEditApp = New-Object System.Windows.Forms.Button
$BtnEditApp.Text = "Edit Application"
$BtnEditApp.Location = New-Object System.Drawing.Point(440, 205)
$BtnEditApp.Size = New-Object System.Drawing.Size(160, 32)
Set-ButtonStyle $BtnEditApp
$BtnEditApp.Add_Click({
    if ($ListBoxApps.SelectedItem) { Show-AppForm -EditAppName $ListBoxApps.SelectedItem; Update-UI }
    else { [System.Windows.Forms.MessageBox]::Show("Select an application first.", "Notice", 0, 48) }
})
$MainForm.Controls.Add($BtnEditApp)

$BtnDeleteApp = New-Object System.Windows.Forms.Button
$BtnDeleteApp.Text = "Delete Application"
$BtnDeleteApp.Location = New-Object System.Drawing.Point(440, 250)
$BtnDeleteApp.Size = New-Object System.Drawing.Size(160, 32)
Set-ButtonStyle $BtnDeleteApp -IsDanger $true
$BtnDeleteApp.Add_Click({
    if ($ListBoxApps.SelectedItem) {
        $AppName = $ListBoxApps.SelectedItem
        $Confirm = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to delete '$AppName' and remove its Watcher Task?", "Confirm Deletion", 4, 32)
        
        if ($Confirm -eq "Yes") {
            $SafeName = $AppName -replace '[\\/:\*\?"<>\| ]', ''
            $AppJsonPath = Join-Path $Global:AppConfigsDir "$SafeName.json"
            $TaskName = "SCCM_Watcher_$SafeName"
            
            if (Test-Path $AppJsonPath) { Remove-Item $AppJsonPath -Force }
            if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            }
            Update-UI
            [System.Windows.Forms.MessageBox]::Show("Application and Task removed.", "Deleted", 0, 64)
        }
    } else { [System.Windows.Forms.MessageBox]::Show("Select an application first.", "Notice", 0, 48) }
})
$MainForm.Controls.Add($BtnDeleteApp)

$InfoPanel = New-Object System.Windows.Forms.Panel
$InfoPanel.BackColor = $InfoBgColor
$InfoPanel.Size = New-Object System.Drawing.Size(400, 32)
$InfoPanel.Location = New-Object System.Drawing.Point(20, 415)
$InfoPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$MainForm.Controls.Add($InfoPanel)

$InfoLabel = New-Object System.Windows.Forms.Label
$InfoLabel.Text = "Every listed application has an active Scheduled Task monitoring its folder."
$InfoLabel.ForeColor = $InfoTextColor
$InfoLabel.AutoSize = $true
$InfoLabel.Location = New-Object System.Drawing.Point(5, 7)
$InfoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$InfoPanel.Controls.Add($InfoLabel)

function Update-UI {
    if (Get-EnvStatus) {
        $LblEnvStatus.Text = "Environment: Configured (Ready)"
        $LblEnvStatus.ForeColor = [System.Drawing.Color]::Green
    } else {
        $LblEnvStatus.Text = "Environment: Not Configured"
        $LblEnvStatus.ForeColor = $DangerRed
    }
    Load-AppsList
}

Update-UI
[void]$MainForm.ShowDialog()
