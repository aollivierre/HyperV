# Get the current timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Define the file path
$filePath = "C:\HelloWorld_$timestamp.txt"

# Write "Hello World" to the file
"Hello World" | Out-File -FilePath $filePath

# Output the file path for confirmation
Write-host "File created at: $filePath"


# Invoke-Expression (Invoke-RestMethod -Uri http://autopilotoobe.ps1.osdeploy.com)