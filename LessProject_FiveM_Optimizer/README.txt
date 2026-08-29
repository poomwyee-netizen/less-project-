LESS PROJECT - FiveM Optimizer

Run Start-LessProject.cmd or LessProject_FiveM_Optimizer.exe as Administrator.
The EXE contains the compressed payload; the separate payload file is kept only for the PowerShell fallback launcher.
The full editable source is LessProject_UI_POWERPLAN_PERFORMANCE_MAX_HWID_LOCK_FIXED_LAN_WIFI.ps1.
The source comments are removed from the distributed payload. This is obfuscation, not encryption.

License access:
- The sign-in gate uses KeyAuth API 1.3 with license + hardware ID validation.
- Application identifiers are public client values; no seller/API secret is stored in this file.
- Create licenses in the KeyAuth dashboard for "Poomwyee's Application" before distributing them.

Important:
- Create a System Restore Point before applying aggressive settings.
- Driver-dependent settings (RSC, ECN, LSO and EEE) are opt-in.
- Defender stays enabled; the Defender option only adds detected game-folder exclusions.
- Provisioned bloatware removal is optional and cannot be restored automatically.
- A restart may be required for BCD, GPU scheduling, TCP or service changes.

GitHub installer usage after uploading the release files:
  powershell -ExecutionPolicy Bypass -File Install-LessProject.ps1 -Repository owner/repository -Ref main
For one-line install, use the commit-pinned CDN installer. It carries a verified runtime bundle and does not need to download individual files.
