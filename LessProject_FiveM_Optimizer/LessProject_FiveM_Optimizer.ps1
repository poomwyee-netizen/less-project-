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

$preloaderEventName = "Local\\LessProject_Preloader_$PID"
$preloaderEvent = $null
$preloaderRunspace = $null
$preloaderPowerShell = $null
$preloaderAsync = $null
try {
    # Show feedback while the compressed PowerShell payload is parsed.  The
    # window lives on a tiny STA runspace so the real application thread stays
    # free to initialize without freezing the desktop.
    $preloaderEvent = [System.Threading.EventWaitHandle]::new($false,[System.Threading.EventResetMode]::ManualReset,$preloaderEventName)
    $env:LESS_PROJECT_PRELOADER_EVENT = $preloaderEventName
    $preloaderRunspace = [runspacefactory]::CreateRunspace()
    $preloaderRunspace.ApartmentState = "STA"
    $preloaderRunspace.ThreadOptions = "ReuseThread"
    $preloaderRunspace.Open()
    $preloaderPowerShell = [powershell]::Create()
    $preloaderPowerShell.Runspace = $preloaderRunspace
    [void]$preloaderPowerShell.AddScript({
        param([string]$eventName)
        try {
            Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase -ErrorAction Stop
            $signal = [System.Threading.EventWaitHandle]::OpenExisting($eventName)
            [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="LESS PROJECT" Width="380" Height="180" WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" ShowInTaskbar="False" Topmost="True" Background="Transparent" FontFamily="Segoe UI">
 <Border Background="#0A0D13" BorderBrush="#243147" BorderThickness="1" CornerRadius="18" Padding="24">
  <StackPanel>
   <TextBlock Text="LESS PROJECT" Foreground="#F3F6FB" FontSize="17" FontWeight="Bold"/>
   <TextBlock Text="Preparing performance controls" Foreground="#8290A5" FontSize="10" Margin="0,5,0,0"/>
   <ProgressBar Height="5" Margin="0,22,0,0" IsIndeterminate="True" Foreground="#E51D50" Background="#202C40"/>
   <TextBlock Text="Loading local modules..." Foreground="#68768B" FontSize="9" Margin="0,14,0,0"/>
  </StackPanel>
 </Border>
</Window>
"@
            $reader = New-Object System.Xml.XmlNodeReader $xaml
            $window = [Windows.Markup.XamlReader]::Load($reader)
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromMilliseconds(90)
            $timer.Add_Tick({
                try {
                    if($signal.WaitOne(0)) { $timer.Stop(); $window.Close() }
                } catch { try { $timer.Stop(); $window.Close() } catch {} }
            }.GetNewClosure())
            $timer.Start()
            $window.ShowDialog() | Out-Null
        } catch {}
    }).AddArgument($preloaderEventName)
    $preloaderAsync = $preloaderPowerShell.BeginInvoke()
} catch {}

try {
    $payloadPath = Join-Path $entryRoot "LessProject_FiveM_Optimizer.payload"
    if(-not (Test-Path -LiteralPath $payloadPath)){
        $payloadPath = Join-Path $env:TEMP "LessProject_FiveM_Optimizer.payload"
    }
    # The expected digest is embedded at build time.  This detects incomplete
    # downloads and casual payload edits before any PowerShell code is parsed.
    $expectedPayloadHash = "41F098CF6E92C24001F88071B9BD651E9671C8DF483073D4125A7F34957214CD"
    if($expectedPayloadHash -match '^[A-Fa-f0-9]{64}$'){
        $actualPayloadHash = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToUpperInvariant()
        if($actualPayloadHash -ne $expectedPayloadHash.ToUpperInvariant()){
            throw "LESS PROJECT payload integrity check failed."
        }
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
} finally {
    try { if($preloaderEvent){ [void]$preloaderEvent.Set() } } catch {}
    try { if($preloaderAsync -and $preloaderPowerShell){ $preloaderPowerShell.EndInvoke($preloaderAsync) | Out-Null } } catch {}
    try { if($preloaderPowerShell){ $preloaderPowerShell.Dispose() } } catch {}
    try { if($preloaderRunspace){ $preloaderRunspace.Close(); $preloaderRunspace.Dispose() } } catch {}
    try { if($preloaderEvent){ $preloaderEvent.Dispose() } } catch {}
    try { Remove-Item Env:LESS_PROJECT_PRELOADER_EVENT -ErrorAction SilentlyContinue } catch {}
}