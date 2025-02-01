function Upload-RemoteHostsFileViaSCP {
    param (
        [string]$remoteHost = "NNOTT-LLW-SL08",
        [string]$username = "share",
        [string]$password = "Default1234"
    )

    # Local script paths based on $PSScriptRoot
    $localScriptPath1 = Join-Path -Path $PSScriptRoot -ChildPath "Update-RemoteHostsFileCommand.ps1"
    $localScriptPath2 = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.txt"

    # Remote directory path
    $remoteDirectory = "C:\Windows\System32\drivers\etc"

    try {
        # Upload the first file to the remote machine using SCP
        $scpUploadCommand1 = "scp `"$localScriptPath1`" `"$username@$remoteHost`:`"$remoteDirectory`""
        Write-Host "Uploading script to $remoteHost via SCP..."
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $scpUploadCommand1" -Wait -NoNewWindow
        
        # Upload the second file to the remote machine using SCP
        $scpUploadCommand2 = "scp `"$localScriptPath2`" `"$username@$remoteHost`:`"$remoteDirectory`""
        Write-Host "Uploading VM hosts file to $remoteHost via SCP..."
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $scpUploadCommand2" -Wait -NoNewWindow
        
        Write-Host "Files uploaded successfully."
    }
    catch {
        Write-Host "Failed to execute the SCP command. Error: $_" -ForegroundColor Red
    }
}

function Execute-RemoteScriptViaSSH {
    param (
        [string]$remoteHost = "NNOTT-LLW-SL08",
        [string]$username = "share",
        [string]$password = "Default1234"
    )

    # Remote script path
    $remoteScriptPath = "C:/Windows/System32/drivers/etc/Update-RemoteHostsFileCommand.ps1"

    try {
        # Construct the SSH command to run the PowerShell script
        $sshCommand = "ssh $username@$remoteHost -pw $password powershell.exe -File `"$remoteScriptPath`""
        
        Write-Host "Executing script on $remoteHost via SSH..."
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $sshCommand" -Wait -NoNewWindow
        
        Write-Host "Script executed successfully via SSH."
    }
    catch {
        Write-Host "Failed to execute the SSH command. Error: $_" -ForegroundColor Red
    }
}

# Main script
Upload-RemoteHostsFileViaSCP -remoteHost "NNOTT-LLW-SL08" -username "share" -password "Default1234"
Execute-RemoteScriptViaSSH -remoteHost "NNOTT-LLW-SL08" -username "share" -password "Default1234"
