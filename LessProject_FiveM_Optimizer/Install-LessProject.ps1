[CmdletBinding()]
param(
    [ValidatePattern('^[^/\\ ]+/[^/\\ ]+$')]
    [string]$Repository = "poomwyee-netizen/less-project-",
    # Pin the verified release so raw GitHub cache cannot mix old and new files.
    [string]$Ref = "a848a0b",
    [string]$ProjectPath = "LessProject_FiveM_Optimizer",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
$appRoot = Join-Path $env:LOCALAPPDATA "LessProject"
$installRoot = Join-Path $appRoot "Release"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("LessProject_" + [guid]::NewGuid().ToString("N"))
$rawRoot = "https://raw.githubusercontent.com/$Repository/$Ref/$ProjectPath"
$files = @(
    "Install-LessProject.ps1",
    "LessProject_FiveM_Optimizer.exe",
    "LessProject_FiveM_Optimizer.payload",
    "LessProject_FiveM_Optimizer.ps1",
    "README.txt",
    "Start-LessProject.cmd"
)

function Test-LessProjectFileLocked {
    param([string]$Path)
    if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ return $false }
    $stream=$null
    try {
        $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        return $false
    } catch {
        return $true
    } finally {
        if($stream){ $stream.Dispose() }
    }
}

function Get-LessProjectSideBySideRoot {
    Join-Path $appRoot ("Release-" + [guid]::NewGuid().ToString("N"))
}

function Save-LessProjectReleaseFile {
    param([string]$FileName,[string]$Destination)
    $lastError=$null
    for($attempt=1;$attempt -le 4;$attempt++){
        try {
            Write-Host "Downloading $FileName (attempt $attempt/4)..." -ForegroundColor DarkCyan
            Invoke-WebRequest -Uri "$rawRoot/$FileName" -OutFile $Destination -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
            if(-not (Test-Path -LiteralPath $Destination -PathType Leaf) -or (Get-Item -LiteralPath $Destination).Length -le 0){
                throw "Downloaded file is empty."
            }
            return
        } catch {
            $lastError=$_.Exception
            if($attempt -lt 4){ Start-Sleep -Seconds $attempt }
        }
    }
    throw "Download failed for $FileName after 4 attempts: $($lastError.Message)"
}

try {
    if($Repository -eq "OWNER/REPOSITORY"){ throw "Configure the GitHub repository first, for example -Repository owner/repository." }
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Write-Host "Downloading LESS PROJECT release..." -ForegroundColor Cyan

    foreach($file in $files){ Save-LessProjectReleaseFile $file (Join-Path $tempRoot $file) }
    $manifestPath = Join-Path $tempRoot "SHA256SUMS.txt"
    Save-LessProjectReleaseFile "SHA256SUMS.txt" $manifestPath

    $manifest = @{}
    foreach($line in Get-Content -LiteralPath $manifestPath){
        if($line -match '^\s*([0-9A-Fa-f]{64})\s+(.+?)\s*$'){
            $manifest[$Matches[2]] = $Matches[1].ToUpperInvariant()
        }
    }
    foreach($file in $files){
        if(-not $manifest.ContainsKey($file)){ throw "SHA256 manifest is missing $file." }
        $actual = (Get-FileHash -LiteralPath (Join-Path $tempRoot $file) -Algorithm SHA256).Hash.ToUpperInvariant()
        if($manifest[$file] -ne $actual){ throw "SHA256 verification failed for $file." }
    }

    $newApp = Join-Path $tempRoot "LessProjectApp"
    New-Item -ItemType Directory -Path $newApp -Force | Out-Null
    foreach($file in $files){ Copy-Item -LiteralPath (Join-Path $tempRoot $file) -Destination (Join-Path $newApp $file) -Force }

    if((Test-Path -LiteralPath $installRoot) -and -not $Force){
        $answer=[System.Windows.MessageBox]::Show("Replace the installed LESS PROJECT release?","LESS PROJECT Update",[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
        if($answer -ne [System.Windows.MessageBoxResult]::Yes){ return }
    }

    # Close the old application before replacing its EXE. This keeps the stable
    # Release path current, so later launches cannot accidentally reopen an older build.
    $runningApps=@(Get-Process -Name "LessProject_FiveM_Optimizer" -ErrorAction SilentlyContinue)
    if($runningApps.Count -gt 0){
        Write-Host "Closing the previous LESS PROJECT release..." -ForegroundColor Yellow
        foreach($runningApp in $runningApps){
            try {
                [void]$runningApp.CloseMainWindow()
                if(-not $runningApp.WaitForExit(2500)){ Stop-Process -Id $runningApp.Id -Force -ErrorAction Stop }
            } catch {
                # If this PowerShell session cannot stop an elevated copy, the
                # lock-safe side-by-side fallback below will still install the update.
            }
        }
        Start-Sleep -Milliseconds 300
    }
    New-Item -ItemType Directory -Path $appRoot -Force | Out-Null

    # A running EXE cannot be replaced on Windows. Install the update side-by-side
    # instead of failing with "Access is denied", then launch the new copy.
    $targetRoot=$installRoot
    $existingExe=Join-Path $installRoot "LessProject_FiveM_Optimizer.exe"
    if(Test-LessProjectFileLocked $existingExe){
        $targetRoot=Get-LessProjectSideBySideRoot
        Write-Host "Existing release is still running; installing the update alongside it..." -ForegroundColor Yellow
    } else {
        try {
            if(Test-Path -LiteralPath $installRoot){ Remove-Item -LiteralPath $installRoot -Recurse -Force -ErrorAction Stop }
            Move-Item -LiteralPath $newApp -Destination $targetRoot -Force -ErrorAction Stop
        } catch {
            # Covers a race where the old process starts after the lock probe.
            if(-not (Test-Path -LiteralPath $newApp)){ throw }
            $targetRoot=Get-LessProjectSideBySideRoot
            Write-Host "The previous release is in use; installing the update alongside it..." -ForegroundColor Yellow
        }
    }
    if(Test-Path -LiteralPath $newApp){ Move-Item -LiteralPath $newApp -Destination $targetRoot -Force -ErrorAction Stop }
    $exe = Join-Path $targetRoot "LessProject_FiveM_Optimizer.exe"
    try { Set-Content -LiteralPath (Join-Path $appRoot "CurrentRelease.txt") -Value $targetRoot -Encoding UTF8 } catch {}
    Write-Host "Installed and verified LESS PROJECT." -ForegroundColor Green
    Start-Process -FilePath $exe -Verb RunAs | Out-Null
} catch {
    Write-Error "LESS PROJECT install failed: $($_.Exception.Message)"
    exit 1
} finally {
    if(Test-Path -LiteralPath $tempRoot){ Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
