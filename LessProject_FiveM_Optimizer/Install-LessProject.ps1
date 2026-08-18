[CmdletBinding()]
param(
    [ValidatePattern('^[^/\\ ]+/[^/\\ ]+$')]
    [string]$Repository = "poomwyee-netizen/less-project-",
    # Use the default branch so the single release package stays in sync with
    # the installer when a new repository is created or a release is updated.
    [string]$Ref = "main",
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
$apiRoot = "https://api.github.com/repos/$Repository/contents/$ProjectPath"
$cacheBust = [DateTime]::UtcNow.Ticks
$apiHeaders = @{
    "User-Agent" = "LESS-PROJECT-Installer"
    "Accept" = "application/vnd.github.raw+json"
}
$archiveName = "LessProject_FiveM_Optimizer_Release.zip"
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
    $sources = @(
        [pscustomobject]@{ Name = "GitHub raw"; Uri = "$rawRoot/$FileName?lp=$cacheBust"; Headers = @{ "User-Agent" = "LESS-PROJECT-Installer" } },
        [pscustomobject]@{ Name = "GitHub API"; Uri = "$apiRoot/$FileName`?ref=$Ref"; Headers = $apiHeaders }
    )
    foreach($source in $sources){
        for($attempt=1;$attempt -le 2;$attempt++){
            try {
                Write-Host "Downloading $FileName via $($source.Name) (attempt $attempt/2)..." -ForegroundColor DarkCyan
                Invoke-WebRequest -Uri $source.Uri -Headers $source.Headers -OutFile $Destination -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
                if(-not (Test-Path -LiteralPath $Destination -PathType Leaf) -or (Get-Item -LiteralPath $Destination).Length -le 0){
                    throw "Downloaded file is empty."
                }
                return
            } catch {
                $lastError=$_.Exception
                if(Test-Path -LiteralPath $Destination){ Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue }
                $status=0
                try { if($_.Exception.Response){ $status=[int]$_.Exception.Response.StatusCode } } catch {}
                # A rate-limited or forbidden endpoint will not recover by
                # retrying the same host; move straight to the API fallback.
                if($status -in @(403,429)){ break }
                if($attempt -lt 2){ Start-Sleep -Seconds $attempt }
            }
        }
    }
    throw "Download failed for $FileName from GitHub raw and API endpoints: $($lastError.Message)"
}

function Get-LessProjectArchiveRoot {
    param([string]$ExtractRoot)
    if(Test-Path -LiteralPath (Join-Path $ExtractRoot "SHA256SUMS.txt") -PathType Leaf){ return $ExtractRoot }
    $nested = Get-ChildItem -LiteralPath $ExtractRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "SHA256SUMS.txt") -PathType Leaf } |
        Select-Object -First 1
    if($nested){ return $nested.FullName }
    return $null
}

function Try-DownloadLessProjectArchive {
    param([string]$DestinationRoot)
    $archivePath = Join-Path $tempRoot $archiveName
    $extractRoot = Join-Path $tempRoot "ArchiveExtract"
    $sources = @(
        [pscustomobject]@{ Name = "GitHub raw"; Uri = "$rawRoot/$archiveName?lp=$cacheBust"; Headers = @{ "User-Agent" = "LESS-PROJECT-Installer" } },
        [pscustomobject]@{ Name = "GitHub API"; Uri = "$apiRoot/$archiveName`?ref=$Ref"; Headers = $apiHeaders }
    )
    foreach($source in $sources){
        try {
            Write-Host "Downloading release package via $($source.Name)..." -ForegroundColor DarkCyan
            Invoke-WebRequest -Uri $source.Uri -Headers $source.Headers -OutFile $archivePath -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
            if(-not (Test-Path -LiteralPath $archivePath -PathType Leaf) -or (Get-Item -LiteralPath $archivePath).Length -le 0){ throw "Downloaded package is empty." }
            if(Test-Path -LiteralPath $extractRoot){ Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
            $sourceRoot = Get-LessProjectArchiveRoot $extractRoot
            if(-not $sourceRoot){ throw "The release package does not contain SHA256SUMS.txt." }
            foreach($file in $files){
                $sourceFile = Join-Path $sourceRoot $file
                if(-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)){ throw "The release package is missing $file." }
                Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $DestinationRoot $file) -Force
            }
            Copy-Item -LiteralPath (Join-Path $sourceRoot "SHA256SUMS.txt") -Destination (Join-Path $DestinationRoot "SHA256SUMS.txt") -Force
            return $true
        } catch {
            $status=0
            try { if($_.Exception.Response){ $status=[int]$_.Exception.Response.StatusCode } } catch {}
            if($status -in @(403,429)){ continue }
        }
    }
    return $false
}

try {
    if($Repository -eq "OWNER/REPOSITORY"){ throw "Configure the GitHub repository first, for example -Repository owner/repository." }
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Write-Host "Downloading LESS PROJECT release..." -ForegroundColor Cyan

    $archiveReady = Try-DownloadLessProjectArchive $tempRoot
    if($archiveReady){
        Write-Host "Release package downloaded; skipping individual file requests." -ForegroundColor Green
    } else {
        Write-Host "Release package unavailable; downloading individual files..." -ForegroundColor Yellow
        foreach($file in $files){ Save-LessProjectReleaseFile $file (Join-Path $tempRoot $file) }
    }
    $manifestPath = Join-Path $tempRoot "SHA256SUMS.txt"
    if(-not $archiveReady){
        Save-LessProjectReleaseFile "SHA256SUMS.txt" $manifestPath
    } elseif(-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)){
        throw "The release package is missing SHA256SUMS.txt."
    }

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
