param (
    [Parameter(Mandatory=$true)]
    [string]$AppName,

    [Parameter(Mandatory=$true)]
    [string]$MsiNetworkPath, 

    [Parameter(Mandatory=$true)]
    [string]$CollectionName,

    [string]$DpGroupName = "All DPs", 
    [string]$SiteCode = "XYZ", 
    
    # Log directory path parameter
    [string]$LogDirectory = "C:\Temp\SCCM_Logs"
)

# 1. Logging Environment Setup
# Create the directory if it does not exist
if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

# Sanitize the application name to be used as a valid file name
$CleanAppName = $AppName -replace '[\\/:\*\?"<>\| ]', '_'
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogDirectory "SCCM_AppCreation_$($CleanAppName)_$($Timestamp).log"

# Start recording the output to the log file
Start-Transcript -Path $LogFile -NoClobber

# --- Start of SCCM Process ---

$ModuleName = "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
if (Test-Path $ModuleName) {
    Import-Module $ModuleName
}

Set-Location "$($SiteCode):"

try {
    Write-Host "Creating Application: $AppName" -ForegroundColor Cyan
    New-CMApplication -Name $AppName -Description "Created automatically via PowerShell script" -ErrorAction Stop

    Write-Host "Adding MSI Deployment Type from $MsiNetworkPath" -ForegroundColor Cyan
    $FolderPath = Split-Path $MsiNetworkPath
    $FileName = Split-Path $MsiNetworkPath -Leaf
    Add-CMMsiDeploymentType -ApplicationName $AppName -ContentLocation $FolderPath -SourceFileName $FileName -Force -ErrorAction Stop

    Write-Host "Distributing content to DP Group: $DpGroupName" -ForegroundColor Cyan
    Start-CMContentDistribution -ApplicationName $AppName -DistributionPointGroupName $DpGroupName -ErrorAction Stop

    Write-Host "Deploying '$AppName' to Collection '$CollectionName'" -ForegroundColor Cyan
    New-CMApplicationDeployment -ApplicationName $AppName -CollectionName $CollectionName -DeployAction Install -DeployPurpose Required -UserNotification DisplaySoftwareCenterOnly -ErrorAction Stop

    Write-Host "Application '$AppName' created, distributed, and deployed successfully!" -ForegroundColor Green

} catch {
    Write-Host "An error occurred during the process:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}

# --- End of SCCM Process ---

# Stop logging
Stop-Transcript

Write-Host "Process finished. Log file saved to: $LogFile" -ForegroundColor Cyan
