LESS PROJECT - FiveM Optimizer

Run Start-LessProject.cmd or LessProject_FiveM_Optimizer.ps1 as Administrator.
The PS1 loader is the default path: it verifies the payload digest, then expands the compressed payload in memory.
The EXE remains available as an optional fallback; the source file is not shipped in the release bundle.
Comments are removed and the runtime is compressed/base64 encoded for distribution. This slows casual inspection, but is not encryption.

Important:
- Create a System Restore Point before applying aggressive settings.
- Driver-dependent settings (RSC, ECN, LSO and EEE) are opt-in.
- Defender stays enabled; the Defender option only adds detected game-folder exclusions.
- Provisioned bloatware removal is optional and cannot be restored automatically.
- A restart may be required for BCD, GPU scheduling, TCP or service changes.

GitHub installer usage after uploading the release files:
  powershell -ExecutionPolicy Bypass -File Install-LessProject.ps1 -Repository owner/repository -Ref main
For one-line install, host Install-LessProject.ps1 and run it with irm | iex after configuring the repository.