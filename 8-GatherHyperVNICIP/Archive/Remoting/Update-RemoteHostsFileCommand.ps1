function Update-RemoteHostsFileCommand {
    param (
        [string]$remoteHostFilePath,
        [string]$localHostEntriesFilePath
    )

    Write-Host "Executing Update-RemoteHostsFileCommand on remote machine..."
    Write-Host "Reading host entries from $localHostEntriesFilePath..."

    # Read all host entries from the local file
    $hostEntries = Get-Content -Path $localHostEntriesFilePath

    foreach ($hostEntry in $hostEntries) {
        Write-Host "Checking if the host entry '$hostEntry' exists in $remoteHostFilePath..."
        if (!(Select-String -Path $remoteHostFilePath -Pattern ([regex]::Escape($hostEntry)) -Quiet)) {
            Write-Host "Host entry '$hostEntry' not found. Adding to $remoteHostFilePath..."
            Add-Content -Path $remoteHostFilePath -Value $hostEntry
            Write-Host 'Hosts file updated on remote machine.'
        } else {
            Write-Host "Host entry '$hostEntry' already exists in the remote hosts file."
        }
    }
}




# Define the paths
$remoteHostFilePath = "C:\Windows\System32\drivers\etc\hosts"
$localHostEntriesFilePath = "$PSScriptRoot\VM_Hosts_IPs.txt"

# Call the function to update the remote hosts file with entries from the local file
Update-RemoteHostsFileCommand -remoteHostFilePath $remoteHostFilePath -localHostEntriesFilePath $localHostEntriesFilePath
