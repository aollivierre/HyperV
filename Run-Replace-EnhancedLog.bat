@echo off
echo.
echo Running Write-EnhancedLog Replacement Script...
echo ============================================
echo.

REM Run the PowerShell script with backup option
powershell.exe -ExecutionPolicy Bypass -File ".\Replace-EnhancedLog.ps1" -BackupFiles

echo.
echo Script execution completed.
pause