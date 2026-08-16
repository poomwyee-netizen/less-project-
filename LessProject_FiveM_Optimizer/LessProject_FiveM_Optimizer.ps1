# LESS-PROJECT-PROTECTED-SCRIPT
# Release loader: the application payload is compressed and stored beside this file.
$ErrorActionPreference = "Stop"
$entryPath = $PSCommandPath
$entryRoot = if($PSScriptRoot){
    $PSScriptRoot
} elseif($entryPath){
    Split-Path -Parent $entryPath
} else {
    [IO.Path]::GetTempPath()
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $admin){
    if($entryPath -and $entryPath.ToLowerInvariant().EndsWith(".ps1")){
        Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",$entryPath) | Out-Null
    } elseif($entryPath){
        Start-Process -FilePath $entryPath -Verb RunAs | Out-Null
    }
    exit
}

try {
    $payloadPath = Join-Path $entryRoot "LessProject_FiveM_Optimizer.payload"
    if(-not (Test-Path -LiteralPath $payloadPath)){
        $payloadPath = Join-Path $env:TEMP "LessProject_FiveM_Optimizer.payload"
    }
    $encoded = [IO.File]::ReadAllText($payloadPath).Trim()
    $compressed = [Convert]::FromBase64String($encoded)
    $input = New-Object IO.MemoryStream(,$compressed)
    $gzip = New-Object IO.Compression.GZipStream($input, [IO.Compression.CompressionMode]::Decompress)
    $reader = New-Object IO.StreamReader($gzip, [Text.Encoding]::UTF8)
    $code = $reader.ReadToEnd()
    $reader.Dispose(); $gzip.Dispose(); $input.Dispose()
    & ([scriptblock]::Create($code))
} catch {
    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
    try {
        [System.Windows.MessageBox]::Show("LESS PROJECT could not start:`n$($_.Exception.Message)","LESS PROJECT",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
    } catch {
        [Console]::Error.WriteLine("LESS PROJECT could not start: $($_.Exception.Message)")
    }
    exit 1
}