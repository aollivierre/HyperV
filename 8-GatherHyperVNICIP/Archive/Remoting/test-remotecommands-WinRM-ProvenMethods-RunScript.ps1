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

function Execute-RemoteScript {
    param (
        [string]$remoteHost = "NNOTT-LLW-SL08",
        [string]$username = "share",
        [string]$password = "Default1234"
    )

    # Remote script path
    $remoteScriptPath = "C:\Windows\System32\drivers\etc\Update-RemoteHostsFileCommand.ps1"

    # Convert credentials to a PSCredential object
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

    # Method 1: Invoke-Command
    Write-Host "Method 1: Invoke-Command - Start"
    Invoke-Command -ComputerName $remoteHost -Credential $credential -ScriptBlock {
        & $using:remoteScriptPath
    }
    Write-Host "Method 1: Invoke-Command - End"

    # # Method 2: New-PSSession + Invoke-Command
    # Write-Host "Method 2: New-PSSession + Invoke-Command - Start"
    # $session = New-PSSession -ComputerName $remoteHost -Credential $credential
    # Invoke-Command -Session $session -ScriptBlock {
    #     & $using:remoteScriptPath
    # }
    # Remove-PSSession -Session $session
    # Write-Host "Method 2: New-PSSession + Invoke-Command - End"

    # # Method 3: Enter-PSSession
    # Write-Host "Method 3: Enter-PSSession - Start"
    # $session = New-PSSession -ComputerName $remoteHost -Credential $credential
    # Enter-PSSession -Session $session
    # & $remoteScriptPath
    # Exit-PSSession
    # Remove-PSSession -Session $session
    # Write-Host "Method 3: Enter-PSSession - End"
}

# Main script
Upload-RemoteHostsFileViaSCP -remoteHost "NNOTT-LLW-SL08" -username "share" -password "Default1234"
Execute-RemoteScript -remoteHost "NNOTT-LLW-SL08" -username "share" -password "Default1234"
