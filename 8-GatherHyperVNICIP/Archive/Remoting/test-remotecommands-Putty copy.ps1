# Define the remote computer name and credentials
[string]$remoteComputer = "NNOTT-LLW-SL08"
[string]$username = "share"
[string]$password = "Default1234"

# Path to putty.exe
$puttyPath = "C:\Program Files\PuTTY\putty.exe"

# Create a temporary file with the command to run
$commandFilePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "putty-command.txt")
Set-Content -Path $commandFilePath -Value "hostname"

# Verify that the command file is created and accessible
if (Test-Path $commandFilePath) {
    Write-Host "Command file created at: $commandFilePath"
    Get-Content -Path $commandFilePath
} else {
    Write-Error "Failed to create command file at: $commandFilePath"
}

# Run the command using putty.exe
& "$puttyPath" -ssh "$username@$remoteComputer" -pw $password -m $commandFilePath

# Clean up the temporary command file
Remove-Item -Path $commandFilePath -Force
