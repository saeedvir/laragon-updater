<#
.SYNOPSIS
    Laragon Tools Updater (Optimized Version)

.DESCRIPTION
    Updates development tools in Laragon to their latest versions with improved error handling and performance.

.PARAMETER DryRun
    Show what would be updated without actually downloading

.PARAMETER Force
    Force update even if version is current

.PARAMETER NoConfirm
    Skip confirmation prompts for closing running processes

.PARAMETER SkipVCRedist
    Skip VC++ Redistributable check and download

.EXAMPLE
    .\update-tools-opt.ps1           # Normal update
    .\update-tools-opt.ps1 -DryRun   # Preview only
    .\update-tools-opt.ps1 -Force    # Force all updates
    .\update-tools-opt.ps1 -NoConfirm # Auto-close running processes
    .\update-tools-opt.ps1 -SkipVCRedist # Skip VC++ runtime check

.NOTES
    Version: 2.1 (Optimized + VC++ Check)
    Requires: PowerShell 5.1+
    Run as: Administrator recommended
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoConfirm,
    [switch]$SkipVCRedist
)

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$ConfirmPreference = "None"

$Script:LaragonBinPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
$Script:TimeoutSec = 300
$Script:MinFileSize = 10000  # Minimum valid file size in bytes

# VC++ Redistributable Configuration (Required for PHP and Apache)
$Script:VCRedist = @{
    DownloadUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    FileName = "vc_redist.x64.exe"
    DisplayName = "Microsoft Visual C++ 2015-2022 Redistributable"
    RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                 "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
}

# ============================================================================
# Tool Definitions
# ============================================================================

$Tools = @{
    apache = @{
        Name = "Apache"
        LatestVersion = "2.4.66"
        BuildDate = "260131"
        ExtractTo = "apache"
        DownloadUrl64 = "https://www.apachelounge.com/download/VS18/binaries/httpd-2.4.66-260131-Win64-VS18.zip"
        DownloadUrl32 = "https://www.apachelounge.com/download/vs18/binaries/httpd-2.4.66-260131-win32-vs18.zip"
        Type = "Apache"
    }
    nginx = @{
        Name = "Nginx"
        CheckUrl = "https://nginx.org/en/download.html"
        Pattern = "nginx-(\d+\.\d+\.\d+)\.zip"
        ExtractTo = "nginx"
        Type = "WebScrape"
    }
    php = @{
        Name = "PHP"
        CheckUrl = "https://windows.php.net/download/"
        Pattern = "php-(\d+\.\d+\.\d+)-nts-Win32-vs(\d+)-x64\.zip"
        ExtractTo = "php"
        VersionedFolder = $true
        Type = "WebScrape"
    }
    mysql = @{
        Name = "MySQL"
        LatestVersion = "9.5.0"
        ExtractTo = "mysql"
        DownloadUrl = "https://downloads.mysql.com/archives/get/p/23/file/mysql-9.5.0-winx64.zip"
        VersionedFolder = $true
        Type = "Direct"
    }
    nodejs = @{
        Name = "Node.js"
        CheckUrl = "https://nodejs.org/dist/latest/"
        Pattern = "node-v(\d+\.\d+\.\d+)-win-x64\.zip"
        ExtractTo = "nodejs"
        Type = "WebScrape"
    }
    composer = @{
        Name = "Composer"
        DownloadUrl = "https://getcomposer.org/composer.phar"
        ExtractTo = "composer"
        Type = "Phar"
    }
    heidisql = @{
        Name = "HeidiSQL"
        ApiUrl = "https://api.github.com/repos/HeidiSQL/HeidiSQL/releases/latest"
        DownloadUrlTemplate = "https://github.com/HeidiSQL/HeidiSQL/releases/download/vVERSION/HeidiSQL_12.15_64_Portable.zip"
        ExtractTo = "heidisql"
        ProcessName = "heidisql"
        Type = "GitHub"
    }
    notepadpp = @{
        Name = "Notepad++"
        ApiUrl = "https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest"
        DownloadUrlTemplate = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/vVERSION/npp.VERSION.portable.x64.zip"
        ExtractTo = "notepad++"
        ProcessName = "notepad++"
        Type = "GitHub"
    }
    python = @{
        Name = "Python"
        CheckUrl = "https://www.python.org/downloads/windows/"
        Pattern = 'Python (\d+\.\d+\.\d+)'
        DownloadUrlTemplate = "https://www.python.org/ftp/python/VERSION/python-VERSION-amd64.exe"
        ExtractTo = "python"
        Type = "Exe"
    }
    sqlitebrowser = @{
        Name = "DB Browser for SQLite"
        ApiUrl = "https://api.github.com/repos/sqlitebrowser/sqlitebrowser/releases/latest"
        DownloadUrlTemplate = "https://github.com/sqlitebrowser/sqlitebrowser/releases/download/vVERSION/DB.Browser.for.SQLite-vVERSION-win64.zip"
        ExtractTo = "SQLiteDatabaseBrowserPortable"
        ProcessName = "DB Browser for SQLite"
        Type = "GitHub"
    }
}

# ============================================================================
# VC++ Redistributable Functions
# ============================================================================

function Test-VCRedistInstalled {
    [OutputType([bool])]
    param()

    try {
        foreach ($regPath in $Script:VCRedist.RegistryPath) {
            if (Test-Path $regPath) {
                $uninstallKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
                foreach ($key in $uninstallKeys) {
                    $displayName = (Get-ItemProperty -Path $key.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
                    if ($displayName -like "*$($Script:VCRedist.DisplayName)*") {
                        return $true
                    }
                }
            }
        }
    }
    catch {
        Write-Status "Error checking VC++ Redistributable: $($_.Exception.Message)" -Color "Yellow"
    }

    return $false
}

function Install-VCRedist {
    [OutputType([bool])]
    param(
        [switch]$DryRun
    )

    $tempPath = Join-Path -Path $env:TEMP -ChildPath $Script:VCRedist.FileName

    Write-Status "Downloading VC++ Redistributable..." -Color "Yellow"

    if ($DryRun) {
        Write-Status "[DRY RUN] Would download and install VC++ Redistributable" -Color "Cyan"
        return $true
    }

    try {
        Invoke-WebRequest -Uri $Script:VCRedist.DownloadUrl -OutFile $tempPath -UseBasicParsing -TimeoutSec 120 -UserAgent $Script:UserAgent

        if (!(Test-Path $tempPath)) {
            Write-Error-Custom "VC++ Redistributable download failed"
            return $false
        }

        Write-Success "VC++ Redistributable downloaded"
        Write-Status "Installing VC++ Redistributable..." -Color "Yellow"

        # Install silently
        $process = Start-Process -FilePath $tempPath -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru

        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-Success "VC++ Redistributable installed successfully"
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
            return $true
        }
        else {
            Write-Error-Custom "VC++ Redistributable installation failed (Exit code: $($process.ExitCode))"
            return $false
        }
    }
    catch {
        Write-Error-Custom "VC++ Redistributable error: $($_.Exception.Message)"
        return $false
    }
}

function Request-VCRedistInstall {
    [OutputType([bool])]
    param(
        [switch]$NoConfirm,
        [switch]$DryRun
    )

    if ($SkipVCRedist) {
        Write-Status "VC++ Redistributable check skipped" -Color "Yellow"
        return $true
    }

    if (Test-VCRedistInstalled) {
        Write-Success "VC++ Redistributable is installed"
        return $true
    }

    Write-Warning-Custom "VC++ Redistributable is NOT installed"
    Write-Status "Required for PHP and Apache to run properly" -Color "Yellow"
    Write-Host ""

    if ($NoConfirm) {
        Write-Status "Auto-installing VC++ Redistributable..." -Color "Yellow"
        return (Install-VCRedist -DryRun:$DryRun)
    }

    $response = Read-Host "  Download and install VC++ Redistributable now? (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
        return (Install-VCRedist -DryRun:$DryRun)
    }

    Write-Status "Skipped: User cancelled - PHP/Apache may not work!" -Color "Yellow"
    return $false
}

# ============================================================================
# Laragon Process Management Functions
# ============================================================================

function Test-LaragonRunning {
    [OutputType([bool])]
    param()

    try {
        $laragon = Get-Process -Name "laragon" -ErrorAction SilentlyContinue
        return ($null -ne $laragon)
    }
    catch {
        return $false
    }
}

function Test-MySQLRunning {
    [OutputType([bool])]
    param()

    try {
        $mysql = Get-Process -Name "mysqld" -ErrorAction SilentlyContinue
        return ($null -ne $mysql)
    }
    catch {
        return $false
    }
}

function Test-ApacheRunning {
    [OutputType([bool])]
    param()

    try {
        $httpd = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
        return ($null -ne $httpd)
    }
    catch {
        return $false
    }
}

function Stop-Laragon {
    [OutputType([bool])]
    param()

    $stopped = $false

    try {
        # First stop Laragon
        $laragon = Get-Process -Name "laragon" -ErrorAction SilentlyContinue
        if ($laragon) {
            $laragon | Stop-Process -Force -ErrorAction Stop
            Write-Success "Laragon stopped"
            $stopped = $true
        }
    }
    catch {
        Write-Error-Custom "Failed to stop Laragon"
    }

    # Wait for Laragon to close
    Start-Sleep -Seconds 2

    # Also stop mysqld if running
    try {
        $mysqld = Get-Process -Name "mysqld" -ErrorAction SilentlyContinue
        if ($mysqld) {
            $mysqld | Stop-Process -Force -ErrorAction Stop
            Write-Success "mysqld.exe stopped"
            $stopped = $true
        }
    }
    catch {
        Write-Status "Note: Could not stop mysqld.exe" -Color "Yellow"
    }

    # Wait a moment
    Start-Sleep -Seconds 1

    # Also stop httpd if running
    try {
        $httpd = Get-Process -Name "httpd" -ErrorAction SilentlyContinue
        if ($httpd) {
            $httpd | Stop-Process -Force -ErrorAction Stop
            Write-Success "httpd.exe stopped"
            $stopped = $true
        }
    }
    catch {
        Write-Status "Note: Could not stop httpd.exe" -Color "Yellow"
    }

    # Final wait for services to close completely
    Start-Sleep -Seconds 2

    return $stopped
}

function Request-StopLaragon {
    [OutputType([bool])]
    param(
        [switch]$NoConfirm
    )

    if (!(Test-LaragonRunning)) {
        Write-Success "Laragon is not running"
        return $true
    }

    Write-Warning-Custom "Laragon is currently running"
    Write-Host ""
    Write-Status "Running processes detected:" -Color "Yellow"

    if (Test-MySQLRunning) {
        Write-Status "  - mysqld.exe (MySQL Server)" -Color "Yellow"
    }
    if (Test-ApacheRunning) {
        Write-Status "  - httpd.exe (Apache Server)" -Color "Yellow"
    }

    Write-Host ""

    if ($NoConfirm) {
        Write-Status "Auto-stopping Laragon..." -Color "Yellow"
        return (Stop-Laragon)
    }

    $response = Read-Host "  Stop Laragon and continue? (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
        return (Stop-Laragon)
    }

    Write-Status "Skipped: User cancelled" -Color "Yellow"
    return $false
}

function Alert-RunningServices {
    param()

    $servicesRunning = @()

    if (Test-MySQLRunning) {
        $servicesRunning += "mysqld.exe (MySQL Server)"
    }
    if (Test-ApacheRunning) {
        $servicesRunning += "httpd.exe (Apache Server)"
    }

    if ($servicesRunning.Count -gt 0) {
        Write-Host ""
        Write-Warning-Custom "The following services are still running:"
        foreach ($service in $servicesRunning) {
            Write-Status "  - $service" -Color "Yellow"
        }
        Write-Host ""
        Write-Status "Recommendation: Stop these services before updating" -Color "Yellow"
        Write-Status "You can stop them from Laragon control panel or Task Manager" -Color "Gray"
        Write-Host ""
    }
}

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Header {
    param([string]$Text)
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Color = "Gray"
    )
    Write-Host "  $Message" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "  [ERR] $Message" -ForegroundColor Red
}

# ============================================================================
# Core Functions
# ============================================================================

function Get-CurrentVersion {
    [OutputType([string])]
    param([string]$Path)

    if (!(Test-Path -Path $Path -PathType Container)) {
        return $null
    }

    try {
        $versionPattern = [regex]::New('(\d+\.\d+\.\d+)')
        $dirs = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue

        foreach ($dir in $dirs) {
            $match = $versionPattern.Match($dir.Name)
            if ($match.Success) {
                return $match.Groups[1].Value
            }
        }
    }
    catch {
        return $null
    }

    return $null
}

function Get-VersionFromGitHub {
    [OutputType([string])]
    param([string]$ApiUrl)

    try {
        $headers = @{
            "User-Agent" = $Script:UserAgent
            "Accept" = "application/vnd.github.v3+json"
        }

        $response = Invoke-WebRequest -Uri $ApiUrl -Headers $headers -UseBasicParsing -TimeoutSec 30
        $json = $response.Content | ConvertFrom-Json

        if ($json.tag_name -match '^v?([\d.]+)') {
            return $matches[1]
        }
    }
    catch {
        Write-Error-Custom "GitHub API error: $($_.Exception.Message)"
    }

    return $null
}

function Get-VersionFromWeb {
    [OutputType([hashtable])]
    param(
        [string]$Url,
        [string]$Pattern
    )

    try {
        $html = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 30 -UserAgent $Script:UserAgent

        if ($html.Content -match $Pattern) {
            return @{
                Success = $true
                Version = $matches[1]
                Matches = $matches
            }
        }
    }
    catch {
        Write-Error-Custom "Could not fetch version from $Url"
    }

    return @{
        Success = $false
        Version = $null
        Matches = $null
    }
}

function Test-ValidZip {
    [OutputType([bool])]
    param([string]$FilePath)

    if (!(Test-Path -Path $FilePath)) {
        return $false
    }

    try {
        $fileSize = (Get-Item -Path $FilePath).Length
        $fileExt = [System.IO.Path]::GetExtension($FilePath).ToLower()

        # Check for very small files
        if ($fileSize -lt $Script:MinFileSize) {
            $content = Get-Content -Path $FilePath -Raw -TotalCount 100 -ErrorAction SilentlyContinue
            if ($content -match '<!DOCTYPE html|<html|<head|<title') {
                Write-Error-Custom "File appears to be an HTML error page"
                Remove-Item -Path $FilePath -Force -ErrorAction SilentlyContinue
                return $false
            }
        }

        # Validate ZIP header
        if ($fileExt -eq '.zip' -and $fileSize -gt 0) {
            $bytes = [System.IO.File]::ReadAllBytes($FilePath)
            if ($bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4B) {
                Write-Error-Custom "File is not a valid ZIP archive"
                Remove-Item -Path $FilePath -Force -ErrorAction SilentlyContinue
                return $false
            }
        }

        return $true
    }
    catch {
        Write-Error-Custom "File validation failed: $($_.Exception.Message)"
        return $false
    }
}

function Download-File {
    [OutputType([bool])]
    param(
        [string]$Url,
        [string]$Dest
    )

    try {
        Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -TimeoutSec $Script:TimeoutSec -UserAgent $Script:UserAgent
        return (Test-ValidZip -FilePath $Dest)
    }
    catch {
        Write-Error-Custom "Download failed: $($_.Exception.Message)"
        if (Test-Path -Path $Dest) {
            Remove-Item -Path $Dest -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

function Extract-Zip {
    [OutputType([bool])]
    param(
        [string]$ZipFile,
        [string]$DestPath,
        [string]$FolderName
    )

    try {
        if (!(Test-Path -Path $DestPath)) {
            New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
        }

        $extractPath = $DestPath
        if ($FolderName) {
            $extractPath = Join-Path -Path $DestPath -ChildPath $FolderName
            if (!(Test-Path -Path $extractPath)) {
                New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
            }
        }

        Expand-Archive -Path $ZipFile -DestinationPath $extractPath -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error-Custom "Extraction failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-RunningProcess {
    [OutputType([bool])]
    param([string]$ProcessName)

    try {
        $process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        return ($null -ne $process)
    }
    catch {
        return $false
    }
}

function Stop-ProcessByName {
    param([string]$ProcessName)

    try {
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop
        Write-Status "Stopped: $ProcessName" -Color "Yellow"
        return $true
    }
    catch {
        Write-Error-Custom "Failed to stop: $ProcessName"
        return $false
    }
}

function Request-ProcessClose {
    [OutputType([bool])]
    param(
        [string]$ProcessName,
        [switch]$NoConfirm
    )

    if (!(Test-RunningProcess -ProcessName $ProcessName)) {
        return $true
    }

    Write-Warning-Custom "Process '$ProcessName' is running"

    if ($NoConfirm) {
        return (Stop-ProcessByName -ProcessName $ProcessName)
    }

    $response = Read-Host "  Close process and continue? (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
        return (Stop-ProcessByName -ProcessName $ProcessName)
    }

    Write-Status "Skipped: User cancelled" -Color "Yellow"
    return $false
}

# ============================================================================
# Tool-Specific Functions
# ============================================================================

function Get-ToolDownloadUrl {
    [OutputType([string])]
    param(
        [hashtable]$Tool,
        [string]$ToolKey,
        [string]$Version,
        [hashtable]$Matches
    )

    switch ($Tool.Type) {
        "Direct" {
            return $Tool.DownloadUrl
        }
        "Apache" {
            $is64Bit = [Environment]::Is64BitOperatingSystem
            return if ($is64Bit) { $Tool.DownloadUrl64 } else { $Tool.DownloadUrl32 }
        }
        "Phar" {
            return $Tool.DownloadUrl
        }
        "GitHub" {
            return $Tool.DownloadUrlTemplate -replace 'VERSION', $Version
        }
        "Exe" {
            return $Tool.DownloadUrlTemplate -replace 'VERSION', $Version
        }
        "WebScrape" {
            switch ($ToolKey) {
                "nginx" {
                    return "https://nginx.org/download/nginx-$Version.zip"
                }
                "php" {
                    $vsVersion = $Matches[2]
                    return "https://windows.php.net/downloads/releases/php-$Version-nts-Win32-vs$vsVersion-x64.zip"
                }
                "nodejs" {
                    return "https://nodejs.org/dist/v$Version/node-v$Version-win-x64.zip"
                }
            }
        }
    }

    return $null
}

function Get-VersionedFolderName {
    [OutputType([string])]
    param(
        [hashtable]$Tool,
        [string]$ToolKey,
        [string]$Version
    )

    if ($Version -eq "latest") {
        return $null
    }

    if ($Tool.VersionedFolder) {
        switch ($ToolKey) {
            "mysql" {
                return "mysql-$Version-winx64"
            }
            "php" {
                return "php-$Version"
            }
        }
    }

    if ($Tool.Type -eq "Apache") {
        return "httpd-$Version-win64-VS18"
    }

    return $null
}

function Get-DownloadUrlType {
    [OutputType([string])]
    param([hashtable]$Tool)

    if ($Tool.Type -eq "Exe") {
        return "exe"
    }
    elseif ($Tool.Type -eq "Phar") {
        return "phar"
    }
    else {
        return "zip"
    }
}

# ============================================================================
# Main Update Logic
# ============================================================================

function Update-Tool {
    param(
        [string]$ToolKey,
        [hashtable]$Tool
    )

    Write-Host "Checking $($Tool.Name)..." -ForegroundColor Yellow

    # Get version and download URL
    $latestVersion = $null
    $downloadUrl = $null
    $versionMatches = $null

    switch ($Tool.Type) {
        "Direct" {
            $latestVersion = $Tool.LatestVersion
            $downloadUrl = $Tool.DownloadUrl
        }
        "Apache" {
            $latestVersion = $Tool.LatestVersion
            $is64Bit = [Environment]::Is64BitOperatingSystem
            $downloadUrl = if ($is64Bit) { $Tool.DownloadUrl64 } else { $Tool.DownloadUrl32 }
            Write-Status "System: $(if($is64Bit){'64-bit'}else{'32-bit'})"
        }
        "Phar" {
            $latestVersion = "latest"
            $downloadUrl = $Tool.DownloadUrl
        }
        "GitHub" {
            $latestVersion = Get-VersionFromGitHub -ApiUrl $Tool.ApiUrl
            if (!$latestVersion) {
                Write-Host ""
                return
            }
            $downloadUrl = $Tool.DownloadUrlTemplate -replace 'VERSION', $latestVersion
        }
        "Exe" {
            $result = Get-VersionFromWeb -Url $Tool.CheckUrl -Pattern $Tool.Pattern
            if (!$result.Success) {
                Write-Host ""
                return
            }
            $latestVersion = $result.Version
            $versionMatches = $result.Matches
            $downloadUrl = $Tool.DownloadUrlTemplate -replace 'VERSION', $latestVersion
        }
        "WebScrape" {
            $result = Get-VersionFromWeb -Url $Tool.CheckUrl -Pattern $Tool.Pattern
            if (!$result.Success) {
                Write-Host ""
                return
            }
            $latestVersion = $result.Version
            $versionMatches = $result.Matches
            $downloadUrl = Get-ToolDownloadUrl -Tool $Tool -ToolKey $ToolKey -Version $latestVersion -Matches $versionMatches
        }
    }

    # Check current version
    $extractPath = Join-Path -Path $Script:LaragonBinPath -ChildPath $Tool.ExtractTo
    $currentVersion = Get-CurrentVersion -Path $extractPath
    $currentVersionDisplay = if ($currentVersion) { $currentVersion } else { "Unknown" }

    Write-Status "Current:  $currentVersionDisplay"
    Write-Status "Latest:   $latestVersion" -Color "Green"
    Write-Status "Download: $downloadUrl"

    # Determine if update is needed
    $needsUpdate = $false
    $skipVersionCheck = $false

    if ($Force) {
        $needsUpdate = $true
    }
    elseif ($latestVersion -eq "latest") {
        $needsUpdate = $true
    }
    elseif (!$currentVersion) {
        $needsUpdate = $true
        $skipVersionCheck = $true
    }
    elseif ($latestVersion -ne "latest") {
        try {
            if ([version]$latestVersion -gt [version]$currentVersion) {
                $needsUpdate = $true
            }
        }
        catch {
            # Version comparison failed
        }
    }

    if (!$needsUpdate) {
        Write-Success "Already up to date"
        Write-Host ""
        return
    }

    if ($skipVersionCheck) {
        Write-Warning-Custom "Version detection skipped (will download)"
    }

    if ($DryRun) {
        Write-Status "[DRY RUN] Would download and extract" -Color "Cyan"
        Write-Host ""
        return
    }

    # Check for running processes
    if ($Tool.ProcessName) {
        if (!(Request-ProcessClose -ProcessName $Tool.ProcessName -NoConfirm:$NoConfirm)) {
            Write-Host ""
            return
        }
    }

    # Download
    $tempFile = Join-Path -Path $env:TEMP -ChildPath (Split-Path -Leaf $downloadUrl)
    Write-Status "Downloading..." -Color "Yellow"

    if (!(Download-File -Url $downloadUrl -Dest $tempFile)) {
        Write-Host ""
        return
    }

    Write-Success "Downloaded successfully"

    # Extract/Copy
    Write-Status "Extracting to: $extractPath"

    $downloadType = Get-DownloadUrlType -Tool $Tool

    if ($downloadType -eq "phar") {
        $destPhar = Join-Path -Path $extractPath -ChildPath "composer.phar"
        Copy-Item -Path $tempFile -Destination $destPhar -Force
        Write-Success "PHAR file copied successfully"
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
    elseif ($downloadType -eq "exe") {
        Write-Warning-Custom "EXE file downloaded. Manual installation may be required."
        $destExe = Join-Path -Path $extractPath -ChildPath "python-latest.exe"
        Copy-Item -Path $tempFile -Destination $destExe -Force
        Write-Status "Downloaded: $destExe"
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
    else {
        $folderName = Get-VersionedFolderName -Tool $Tool -ToolKey $ToolKey -Version $latestVersion

        if (Extract-Zip -ZipFile $tempFile -DestPath $extractPath -FolderName $folderName) {
            if ($folderName) {
                Write-Success "Extracted to: $folderName"
            }
            else {
                Write-Success "Extracted successfully"
            }
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Error-Custom "Extraction failed"
        }
    }

    Write-Host ""
}

# ============================================================================
# Main Execution
# ============================================================================

try {
    Write-Header "Laragon Tools Updater (Optimized)"
    Write-Host ""
    Write-Status "Note: Apache updates use direct download links" -Color "Yellow"
    Write-Host ""

    # Check VC++ Redistributable (required for PHP and Apache)
    Write-Status "Checking VC++ Redistributable..." -Color "Cyan"
    Request-VCRedistInstall -NoConfirm:$NoConfirm -DryRun:$DryRun
    Write-Host ""

    # Check and stop Laragon if running
    Write-Status "Checking Laragon status..." -Color "Cyan"
    if (!(Request-StopLaragon -NoConfirm:$NoConfirm)) {
        Write-Host ""
        Write-Warning-Custom "Laragon is still running. Updates may fail!"
        Write-Status "Continuing without stopping Laragon..." -Color "Yellow"
        Write-Host ""
    }
    Write-Host ""

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($toolKey in $Tools.Keys) {
        Update-Tool -ToolKey $toolKey -Tool $Tools[$toolKey]
    }

    $stopwatch.Stop()

    # Alert about running services after update
    Alert-RunningServices

    Write-Host ""
    $elapsedTime = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
    Write-Header "Update complete! (${elapsedTime}s)"
}
catch {
    Write-Error-Custom "Fatal error: $($_.Exception.Message)"
    exit 1
}
