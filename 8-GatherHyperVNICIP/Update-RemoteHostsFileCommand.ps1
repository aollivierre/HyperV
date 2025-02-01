function Update-RemoteHostsFileCommand {
    param (
        [string]$remoteHostFilePath,
        [PSCustomObject[]]$hostEntries
    )

    Write-Host "Executing Update-RemoteHostsFileCommand on remote machine..."
    Write-Host "Reading host entries from the provided content..."

    foreach ($entry in $hostEntries) {
        $hostEntry = "$($entry.IPAddress) $($entry.HostName) # VM Name: $($entry.VMName)"
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
