param (
    [string]$AppConfigPath,
    [string]$DroppedMsiPath = "" 
)

$EnvConfig = Get-Content (Join-Path $PSScriptRoot "Env-Config.json") -Raw | ConvertFrom-Json
$AppConfig = Get-Content $AppConfigPath -Raw | ConvertFrom-Json

$AppName = $AppConfig.AppName
$SiteCode = $EnvConfig.SiteCode
$LogDir = $EnvConfig.LogDirectory

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

$SafeAppName = $AppName -replace '[\\/:\*\?"<>\| ]', '_'
$LogFile = Join-Path $LogDir "SCCM_AppCreation_$SafeAppName.log"

function Write-Log([string]$Message, [string]$Level="INFO") {
    $LogEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
}

# --- SYSTEM-WIDE MUTEX LOCK ---
$MutexName = "Global\SCCM_CreateApp_$SafeAppName"
$Mutex = New-Object System.Threading.Mutex($false, $MutexName)
$LockAcquired = $false

try {
    # WaitOne(0) checks immediately without waiting. Returns $false if already locked.
    $LockAcquired = $Mutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    # Previous process crashed without releasing; we now own the lock.
    $LockAcquired = $true
}

if (-not $LockAcquired) {
    Write-Log "Another instance of Create-SCCMApp.ps1 is already running for '$AppName'. Exiting to prevent duplicate execution." "WARN"
    $Mutex.Dispose()
    exit 0
}
# ------------------------------

try {
    if ($DroppedMsiPath -ne "" -and (Test-Path $DroppedMsiPath)) {
        $MsiNetworkPath = $DroppedMsiPath
    } else {
        $MsiNetworkPath = $AppConfig.MsiNetworkPath
    }

    Write-Log "Starting creation phase for: $AppName"
    Write-Log "Target MSI File: $MsiNetworkPath"

    if (-not $MsiNetworkPath.EndsWith(".msi", [System.StringComparison]::InvariantCultureIgnoreCase)) {
        Write-Log "CRITICAL ERROR: The path '$MsiNetworkPath' is not an MSI file. SCCM requires a direct path to an .msi file." "ERROR"
        exit 1
    }

    if (Test-Path $EnvConfig.SccmModulePath) { Import-Module $EnvConfig.SccmModulePath }
    if (-not (Get-PSDrive -Name $SiteCode -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME -Description "SCCM" | Out-Null
    }
    Set-Location "$($SiteCode):"

    try {
        Write-Log "Resolving exact Collection ID for '$($AppConfig.CollectionName)'"
        
        $TargetCollection = Get-CMCollection -Name $AppConfig.CollectionName
        
        if (-not $TargetCollection) {
            throw "Could not find any collection named '$($AppConfig.CollectionName)'."
        }
        
        if ($TargetCollection.Count -gt 1) {
            throw "Found $($TargetCollection.Count) collections matching '$($AppConfig.CollectionName)'. Please use the exact Collection ID in the configuration GUI instead of the name to avoid conflicts."
        }

        $ExactCollectionId = $TargetCollection.CollectionID
        Write-Log "Resolved Collection ID: $ExactCollectionId"

        New-CMApplication -Name $AppName -Description "Auto-deployed" -ErrorAction Stop
        Add-CMMsiDeploymentType -ApplicationName $AppName -ContentLocation $MsiNetworkPath -Force -ErrorAction Stop
        Start-CMContentDistribution -ApplicationName $AppName -DistributionPointGroupName $AppConfig.DpGroupName -ErrorAction Stop
        
        New-CMApplicationDeployment -ApplicationName $AppName -CollectionId $ExactCollectionId -DeployAction Install -DeployPurpose Required -UserNotification DisplaySoftwareCenterOnly -ErrorAction Stop
        
        Write-Log "Deployment Successful!"
        Send-MailMessage -SmtpServer $EnvConfig.SmtpServer -From $EnvConfig.EmailFrom -To $EnvConfig.EmailTo -Subject "SCCM Success: $AppName" -Body "Deployed $AppName using file $MsiNetworkPath to Collection ID $ExactCollectionId" -Encoding UTF8
    } catch {
        Write-Log $_.Exception.Message "ERROR"
        Send-MailMessage -SmtpServer $EnvConfig.SmtpServer -From $EnvConfig.EmailFrom -To $EnvConfig.EmailTo -Subject "SCCM FAILED: $AppName" -Body "Error:`n$($_.Exception.Message)" -Encoding UTF8
    }
} finally {
    # Always release the lock when the script finishes or exits
    if ($LockAcquired) {
        $Mutex.ReleaseMutex()
    }
    $Mutex.Dispose()
}
