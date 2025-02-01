function Update-RemoteHostsFileViaSSH {
    param (
        [string]$remoteHost = "NNOTT-LLW-SL08",
        [string]$username = "share",
        [string]$password = "Default1234",
        [string]$remoteScriptPath = "C:\Temp\Update-RemoteHostsFileCommand.ps1",
        [string]$remoteHostFilePath = "C:\Windows\System32\drivers\etc\hosts",
        [string]$hostEntry = "192.168.100.147 DESKTOP-9KHVRUI"
    )

    # Local script path based on $PSScriptRoot
    $localScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Update-RemoteHostsFileCommand.ps1"

    # Create a secure string for the password
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    # Create a PSCredential object
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

    # Upload the script to the remote machine using SCP
    $scpUploadCommand = "scp `"$localScriptPath`" `"$username@$remoteHost`: `"$remoteScriptPath`""
    try {
        Write-Host "Uploading script to $remoteHost via SCP..."
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $scpUploadCommand" -Wait -NoNewWindow

        # Execute the script on the remote machine using SSH
        Write-Host "Connecting to $remoteHost via SSH to execute the script..."
        $session = New-PSSession -HostName $remoteHost -UserName $username -SSHTransport -Credential $credential
        Invoke-Command -Session $session -ScriptBlock {
            param (
                $remoteScriptPath,
                $remoteHostFilePath,
                $hostEntry
            )
            . $remoteScriptPath
            Update-RemoteHostsFileCommand -remoteHostFilePath $remoteHostFilePath -hostEntry $hostEntry
        } -ArgumentList $remoteScriptPath, $remoteHostFilePath, $hostEntry
        Remove-PSSession -Session $session

        Write-Host "SSH command executed successfully."
    }
    catch {
        Write-Host "Failed to execute the SCP or SSH command. Error: $_" -ForegroundColor Red
    }
}

# Example usage of the main function
Update-RemoteHostsFileViaSSH
