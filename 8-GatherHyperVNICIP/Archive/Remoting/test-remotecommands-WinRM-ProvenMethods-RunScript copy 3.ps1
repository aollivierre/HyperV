function Execute-RemoteScript {
    param (
        [string]$remoteHost = "NNOTT-LLW-SL08",
        [string]$username = "share",
        [string]$password = "Default1234"
    )

    # Local script paths based on $PSScriptRoot
    $localScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Update-RemoteHostsFileCommand.ps1"
    $localHostEntriesFilePath = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.txt"

    # Read the content of the local script and host entries file
    $scriptContent = Get-Content -Path $localScriptPath -Raw
    $hostEntries = Get-Content -Path $localHostEntriesFilePath

    # Convert credentials to a PSCredential object
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

    # Method 1: Invoke-Command
    Write-Host "Method 1: Invoke-Command - Start"
    Invoke-Command -ComputerName $remoteHost -Credential $credential -ScriptBlock {
        param ($scriptContent, $hostEntries)

        # Define the function to update the hosts file
        $updateHostsScript = [scriptblock]::Create($scriptContent)
        . $updateHostsScript

        # Define the paths
        $remoteHostFilePath = "C:\Windows\System32\drivers\etc\hosts"

        # Call the function to update the remote hosts file with entries from the provided content
        Update-RemoteHostsFileCommand -remoteHostFilePath $remoteHostFilePath -hostEntries $hostEntries
    } -ArgumentList $scriptContent, $hostEntries
    Write-Host "Method 1: Invoke-Command - End"
}

# Main script
Execute-RemoteScript -remoteHost "NNOTT-LLW-SL08" -username "share" -password "Default1234"
