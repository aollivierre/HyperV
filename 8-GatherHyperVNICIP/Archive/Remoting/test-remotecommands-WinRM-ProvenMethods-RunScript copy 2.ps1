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
    $hostEntries = Get-Content -Path $localHostEntriesFilePath -Raw

    # Convert credentials to a PSCredential object
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

    # Method 1: Invoke-Command
    Write-Host "Method 1: Invoke-Command - Start"
    Invoke-Command -ComputerName $remoteHost -Credential $credential -ScriptBlock {
        param ($scriptContent, $hostEntries)

        # Define the function to update the hosts file
        function Update-RemoteHostsFileCommand {
            param (
                [string]$remoteHostFilePath,
                [string]$hostEntries
            )

            Write-Host "Executing Update-RemoteHostsFileCommand on remote machine..."
            Write-Host "Reading host entries from the provided content..."

            # Split host entries into an array
            $hostEntriesArray = $hostEntries -split "`n"

            foreach ($hostEntry in $hostEntriesArray) {
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

        # Call the function to update the remote hosts file with entries from the provided content
        Update-RemoteHostsFileCommand -remoteHostFilePath $remoteHostFilePath -hostEntries $hostEntries
    } -ArgumentList $scriptContent, $hostEntries
    Write-Host "Method 1: Invoke-Command - End"
}

# Main script
Execute-RemoteScript -remoteHost "NNOTT-LLW-SL08" -username "share" -password "Default1234"
