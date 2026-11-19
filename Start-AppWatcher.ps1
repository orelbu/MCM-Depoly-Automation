param (
    [Parameter(Mandatory=$true)]
    [string]$AppConfigPath
)

if (-not (Test-Path $AppConfigPath)) {
    Write-Error "Configuration file not found: $AppConfigPath"
    exit
}

# Read Application Configuration
$AppConfig = Get-Content -Path $AppConfigPath -Raw | ConvertFrom-Json
$FolderToWatch = $AppConfig.FolderToWatch

if (-not (Test-Path $FolderToWatch)) {
    Write-Error "Monitored folder not found: $FolderToWatch"
    exit
}

# Set up the FileSystemWatcher
$Watcher = New-Object System.IO.FileSystemWatcher
$Watcher.Path = $FolderToWatch
$Watcher.Filter = "*.msi"
$Watcher.IncludeSubdirectories = $false
$Watcher.EnableRaisingEvents = $true

# Define the action to take when a new MSI is dropped
$Action = {
    $FilePath = $Event.SourceEventArgs.FullPath
    $FileName = $Event.SourceEventArgs.Name
    $ChangeType = $Event.SourceEventArgs.ChangeType
    
    $LogMsg = "[$(Get-Date)] Detected $ChangeType: $FileName in $FolderToWatch"
    Write-Host $LogMsg
    
    # Wait 15 seconds to ensure the file has completely finished copying over the network
    Start-Sleep -Seconds 15
    
    # Trigger the Create Application Script
    $DeployScript = Join-Path $PSScriptRoot "Create-SCCMApp.ps1"
    
    if (Test-Path $DeployScript) {
        # Execute the script and pass the new MSI path explicitly
        & powershell.exe -ExecutionPolicy Bypass -File "$DeployScript" -AppName "$($AppConfig.AppName)" -MsiNetworkPath "$FilePath" -CollectionName "$($AppConfig.CollectionName)" -DpGroupName "$($AppConfig.DpGroupName)"
    }
}

# Register the event to trigger on file Creation
Register-ObjectEvent $Watcher "Created" -Action $Action | Out-Null

Write-Host "Monitoring started for folder: $FolderToWatch"

# Keep the background job alive indefinitely
while ($true) {
    Start-Sleep -Seconds 60
}
