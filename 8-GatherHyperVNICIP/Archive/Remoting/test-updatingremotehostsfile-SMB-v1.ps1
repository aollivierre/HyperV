# Define the credentials
$hostname = "NNOTT-LLW-SL08"
$username = "$hostname\share"
$password = "Default1234"
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

# Define the remote hosts file path
$remoteHostFilePath = "\\$hostname\etc\hosts"

# Define the entry to add
$hostEntry = "192.168.100.147`tDESKTOP-9KHVRUI"

# Create a mapped drive to the remote host
$driveName = "Z:"
New-PSDrive -Name $driveName -PSProvider FileSystem -Root "\\$hostname\etc" -Credential $credential -Persist

# Read the existing remote hosts file
Write-Host "Reading remote hosts file..."
$remoteHostsFileContent = Get-Content -Path "$driveName\hosts"

# Check if the entry already exists in the remote hosts file
if ($remoteHostsFileContent -notcontains $hostEntry) {
    Write-Host "Updating remote hosts file..."
    # Add the new entry to the remote hosts file
    Add-Content -Path "$driveName\hosts" -Value $hostEntry
    Write-Host "Hosts file updated on remote machine."
} else {
    Write-Host "Host entry already exists in the remote hosts file."
}

# Remove the mapped drive
Remove-PSDrive -Name $driveName
