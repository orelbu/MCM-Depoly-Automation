param (
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    
    [string]$SiteCode = "XYZ" # <-- Change this to your Site Code
)

# Import the SCCM module (if it doesn't load automatically)
$ModuleName = "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
if (Test-Path $ModuleName) {
    Import-Module $ModuleName
}

# Change directory to the SCCM drive
Set-Location "$($SiteCode):"

Write-Host "Searching for application: $AppName" -ForegroundColor Cyan
$App = Get-CMApplication -Name $AppName

if (-not $App) {
    Write-Host "Application '$AppName' was not found in SCCM." -ForegroundColor Red
    return
}

# Search for deployments associated with the application
$Deployments = Get-CMApplicationDeployment -Name $AppName

if ($Deployments) {
    Write-Host "Found $($Deployments.Count) deployment(s). Removing them..." -ForegroundColor Yellow
    foreach ($Deployment in $Deployments) {
        Write-Host "Removing deployment from collection: $($Deployment.CollectionName)"
        Remove-CMApplicationDeployment -Name $AppName -CollectionName $Deployment.CollectionName -Force
    }
} else {
    Write-Host "No deployments found for '$AppName'." -ForegroundColor Green
}

# Re-check to ensure all deployments were successfully removed
$RemainingDeployments = Get-CMApplicationDeployment -Name $AppName

if (-not $RemainingDeployments) {
    Write-Host "All deployments removed successfully. Deleting the application '$AppName'..." -ForegroundColor Yellow
    Remove-CMApplication -Name $AppName -Force
    Write-Host "Application '$AppName' deleted successfully." -ForegroundColor Green
} else {
    Write-Host "Error: Could not remove all deployments. The application will NOT be deleted to prevent issues." -ForegroundColor Red
}
