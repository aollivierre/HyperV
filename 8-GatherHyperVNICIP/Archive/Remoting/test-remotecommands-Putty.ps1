# # Define the remote computer name and credentials
# [string]$remoteComputer = "NNOTT-LLW-SL08"
# [string]$username = "share"
# [string]$password = "Default1234"

# # Path to putty.exe
# $puttyPath = "C:\Program Files\PuTTY\putty.exe"

# # Function to execute a command using putty.exe
# function Execute-PuttyCommand {
#     param (
#         [string]$command,
#         [string]$options = ""
#     )

#     if (Test-Path $puttyPath) {
#         try {
#             $process = Start-Process -FilePath $puttyPath -ArgumentList "-ssh -l $username -pw $password $options $remoteComputer -m echo.bat" -Wait -PassThru -NoNewWindow
#             if ($process.ExitCode -ne 0) {
#                 Write-Error "PuTTY execution failed with exit code: $($process.ExitCode)"
#             }
#         } catch {
#             Write-Error "PuTTY failed: $_"
#         }
#     } else {
#         Write-Error "PuTTY path not found: $puttyPath"
#     }
# }

# # Create a temporary batch file to hold the command
# $batchFilePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "echo.bat")
# Set-Content -Path $batchFilePath -Value "hostname"

# # Method 1: Basic command execution
# Write-Host "Method 1: Basic command execution - Start" -ForegroundColor Cyan
# Execute-PuttyCommand -command "hostname"
# Write-Host "Method 1: Basic command execution - End" -ForegroundColor Cyan

# # Method 2: Using a specific port
# Write-Host "Method 2: Using a specific port - Start" -ForegroundColor Cyan
# Execute-PuttyCommand -command "hostname" -options "-P 22"
# Write-Host "Method 2: Using a specific port - End" -ForegroundColor Cyan

# # Method 3: Disabling agent forwarding
# Write-Host "Method 3: Disabling agent forwarding - Start" -ForegroundColor Cyan
# Execute-PuttyCommand -command "hostname" -options "-A"
# Write-Host "Method 3: Disabling agent forwarding - End" -ForegroundColor Cyan

# # Method 4: Enabling agent forwarding
# Write-Host "Method 4: Enabling agent forwarding - Start" -ForegroundColor Cyan
# Execute-PuttyCommand -command "hostname" -options "-a"
# Write-Host "Method 4: Enabling agent forwarding - End" -ForegroundColor Cyan

# # Method 5: Using a specific SSH key
# Write-Host "Method 5: Using a specific SSH key - Start" -ForegroundColor Cyan
# $keyPath = "C:\Path\To\Your\PrivateKey.ppk"
# Execute-PuttyCommand -command "hostname" -options "-i $keyPath"
# Write-Host "Method 5: Using a specific SSH key - End" -ForegroundColor Cyan

# # Method 6: Disabling host key check
# Write-Host "Method 6: Disabling host key check - Start" -ForegroundColor Cyan
# Execute-PuttyCommand -command "hostname" -options "-noagent -hostkey *"
# Write-Host "Method 6: Disabling host key check - End" -ForegroundColor Cyan

# # Method 7: Logging the session to a file
# Write-Host "Method 7: Logging the session to a file - Start" -ForegroundColor Cyan
# $logPath = "C:\Path\To\LogFile.log"
# Execute-PuttyCommand -command "hostname" -options "-log $logPath"
# Write-Host "Method 7: Logging the session to a file - End" -ForegroundColor Cyan

# # Method 8: Enabling compression
# Write-Host "Method 8: Enabling compression - Start" -ForegroundColor Cyan
# Execute-PuttyCommand -command "hostname" -options "-C"
# Write-Host "Method 8: Enabling compression - End" -ForegroundColor Cyan

# # Method 9: Specifying a terminal type
# Write-Host "Method 9: Specifying a terminal type - Start" -ForegroundColor Cyan
# Execute-PuttyCommand -command "hostname" -options "-T xterm"
# Write-Host "Method 9: Specifying a terminal type - End" -ForegroundColor Cyan

# # Method 10: Setting a window title
# Write-Host "Method 10: Setting a window title - Start" -ForegroundColor Cyan
# Execute-PuttyCommand -command "hostname" -options "-title MyPuTTYSession"
# Write-Host "Method 10: Setting a window title - End" -ForegroundColor Cyan

# # Clean up temporary batch file
# Remove-Item -Path $batchFilePath -Force










& "C:\Program Files\PuTTY\putty.exe" -ssh share@NNOTT-LLW-SL08 -pw Default1234