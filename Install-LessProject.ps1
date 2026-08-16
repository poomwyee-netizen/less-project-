[CmdletBinding()]
param(
    [ValidatePattern('^[^/\\ ]+/[^/\\ ]+$')]
    [string]$Repository = "poomwyee-netizen/less-project-",
    [string]$Ref = "main",
    [string]$AssetPath = "release/LessProject_FiveM_Optimizer_Release.zip",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
$appRoot = Join-Path $env:LOCALAPPDATA "LessProject"
$installRoot = Join-Path $appRoot "Release"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("LessProject_" + [guid]::NewGuid().ToString("N"))
$zipName = Split-Path $AssetPath -Leaf
$zipPath = Join-Path $tempRoot $zipName
$hashPath = "$zipPath.sha256"
$rawRoot = "https://raw.githubusercontent.com/$Repository/$Ref"

try {
    if($Repository -eq "OWNER/REPOSITORY"){ throw "Configure the GitHub repository first, for example -Repository owner/repository." }
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    Write-Host "Downloading LESS PROJECT release..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "$rawRoot/$AssetPath" -OutFile $zipPath -UseBasicParsing
    Invoke-WebRequest -Uri "$rawRoot/$AssetPath.sha256" -OutFile $hashPath -UseBasicParsing

    $expected = ((Get-Content -LiteralPath $hashPath -Raw).Trim() -split '\s+')[0].ToUpperInvariant()
    $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToUpperInvariant()
    if($expected -ne $actual){ throw "SHA256 verification failed. Expected $expected, got $actual." }

    $extractRoot = Join-Path $tempRoot "Extracted"
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
    $newApp = Join-Path $tempRoot "LessProjectApp"
    New-Item -ItemType Directory -Path $newApp -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $extractRoot "LessProject_FiveM_Optimizer.exe") -Destination $newApp -Force
    Copy-Item -LiteralPath (Join-Path $extractRoot "LessProject_FiveM_Optimizer.payload") -Destination $newApp -Force
    Copy-Item -LiteralPath (Join-Path $extractRoot "LessProject_FiveM_Optimizer.ps1") -Destination $newApp -Force
    Copy-Item -LiteralPath (Join-Path $extractRoot "README.txt") -Destination $newApp -Force

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
