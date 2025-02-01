#================================================
#  [PostOS] SetupComplete CMD Command Line
#================================================
Write-Host -ForegroundColor Green "Create D:\Code\GitHub\CB\CB\Hyper-V\0-Convert-ISO-VHDX-WIM-PPKG-Injection\SetupTasks\SetupComplete.cmd"
$SetupCompleteCMD = @'
powershell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
powershell.exe -Command "& {IEX (IRM oobetasks.osdcloud.ch)}"
'@
$SetupCompleteCMD | Out-File -FilePath 'D:\Code\GitHub\CB\CB\Hyper-V\0-Convert-ISO-VHDX-WIM-PPKG-Injection\SetupTasks\SetupComplete.cmd' -Encoding ascii -Force