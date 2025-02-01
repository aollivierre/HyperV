function Update-RemoteHostsFile {
    param (
        [string]$remoteHostFilePath = "\\NNOTT-LLW-SL08\etc\hosts",
        [string]$hostEntry = "192.168.100.147`tDESKTOP-9KHVRUI",
        [string]$username = "NNOTT-LLW-SL08\share",
        [string]$password = "Default1234"
    )

    # Convert password to secure string and create credential object
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

    # Use Invoke-Command to run the command on the remote host
    $scriptBlock = {
        param ($remoteHostFilePath, $hostEntry)
        
        # Read the existing remote hosts file
        $remoteHostsFileContent = Get-Content -Path $remoteHostFilePath

        # Check if the entry already exists in the remote hosts file
        if ($remoteHostsFileContent -notcontains $hostEntry) {
            Write-Host "Updating remote hosts file..."
            # Add the new entry to the remote hosts file
            Add-Content -Path $remoteHostFilePath -Value $hostEntry
            Write-Host "Hosts file updated on remote machine."
        } else {
            Write-Host "Host entry already exists in the remote hosts file."
        }
    }

    # Execute the script block on the remote machine
    Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $remoteHostFilePath, $hostEntry -Credential $credential -ComputerName "NNOTT-LLW-SL08"
}

# Example usage of the function
Update-RemoteHostsFile
