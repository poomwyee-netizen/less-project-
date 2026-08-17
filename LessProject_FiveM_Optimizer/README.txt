LESS PROJECT - FiveM Optimizer

Run Start-LessProject.cmd or LessProject_FiveM_Optimizer.exe as Administrator.
The EXE contains the compressed payload; the separate payload file is kept only for the PowerShell fallback launcher.
The source comments are removed for distribution.
This is obfuscation, not encryption; do not use it to hide unsafe changes.

Important:
- Create a System Restore Point before applying aggressive settings.
- Driver-dependent settings (RSC, ECN, LSO and EEE) are opt-in.
- Defender stays enabled; the Defender option only adds detected game-folder exclusions.
- Provisioned bloatware removal is optional and cannot be restored automatically.
- A restart may be required for BCD, GPU scheduling, TCP or service changes.

GitHub one-line install (verified release):
  irm https://raw.githubusercontent.com/poomwyee-netizen/less-project-/main/LessProject_FiveM_Optimizer/Install-LessProject.ps1 | iex

If raw.githubusercontent.com returns HTTP 429, use the GitHub API fallback below.
It uses one API request to fetch the installer and the installer automatically
falls back to the API for release files when the raw host is rate-limited:
  $u='https://api.github.com/repos/poomwyee-netizen/less-project-/contents/LessProject_FiveM_Optimizer/Install-LessProject.ps1?ref=main'; $j=Invoke-RestMethod -Uri $u -Headers @{'User-Agent'='LESS-PROJECT-Installer';'Accept'='application/vnd.github+json'}; iex ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($j.content -replace '\s',''))))
