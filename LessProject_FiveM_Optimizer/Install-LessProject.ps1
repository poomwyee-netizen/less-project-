[CmdletBinding()]
param(
    [ValidatePattern('^[^/\\ ]+/[^/\\ ]+$')]
    [string]$Repository = "poomwyee-netizen/less-project-",
    # Pin the verified release so raw GitHub cache cannot mix old and new files.
    [string]$Ref = "713e19a",
    [string]$ProjectPath = "LessProject_FiveM_Optimizer",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
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

try {
    if($Repository -eq "OWNER/REPOSITORY"){ throw "Configure the GitHub repository first, for example -Repository owner/repository." }
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Write-Host "Downloading LESS PROJECT release..." -ForegroundColor Cyan

    foreach($file in $files){
        Invoke-WebRequest -Uri "$rawRoot/$file" -OutFile (Join-Path $tempRoot $file) -UseBasicParsing
    }
    $manifestPath = Join-Path $tempRoot "SHA256SUMS.txt"
    Invoke-WebRequest -Uri "$rawRoot/SHA256SUMS.txt" -OutFile $manifestPath -UseBasicParsing

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
    New-Item -ItemType Directory -Path $appRoot -Force | Out-Null
    if(Test-Path -LiteralPath $installRoot){ Remove-Item -LiteralPath $installRoot -Recurse -Force }
    Move-Item -LiteralPath $newApp -Destination $installRoot -Force
    $exe = Join-Path $installRoot "LessProject_FiveM_Optimizer.exe"
    Write-Host "Installed and verified LESS PROJECT." -ForegroundColor Green
    Start-Process -FilePath $exe -Verb RunAs | Out-Null
} catch {
    Write-Error "LESS PROJECT install failed: $($_.Exception.Message)"
    exit 1
} finally {
    if(Test-Path -LiteralPath $tempRoot){ Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
