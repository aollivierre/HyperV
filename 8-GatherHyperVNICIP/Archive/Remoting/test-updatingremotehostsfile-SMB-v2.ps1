function Update-RemoteHostsFile {
    param (
        [string]$hostname = "NNOTT-LLW-SL08",
        [string]$username = "NNOTT-LLW-SL08\share",
        [string]$password = "Default1234",
        [string]$remoteHostFilePath = "\\NNOTT-LLW-SL08\etc\hosts",
        [string]$hostEntry = "192.168.100.147`tDESKTOP-9KHVRUI"
    )

    # Convert password to secure string and create credential object
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

    # Define the PSDrive name
    $driveName = "Z"

    # Remove any existing PSDrive with the same name
    if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $driveName -Force
    }

    # Attempt to create the PSDrive
    try {
        Write-Host "Attempting to create PSDrive '$driveName' for UNC path '\\$hostname\etc'."
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root "\\$hostname\etc" -Credential $credential -Scope Global -Persist -ErrorAction Stop
        Write-Host "PSDrive '$driveName' created for UNC path '\\$hostname\etc'."
    }
    catch {
        Write-Host "Failed to create PSDrive '$driveName'. Error: $_" -ForegroundColor Red
        return
    }

    # Verify if PSDrive was successfully created
    if (-not (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue)) {
        Write-Host "Failed to verify PSDrive '$driveName'. Exiting." -ForegroundColor Red
        return
    }

    # Read the existing remote hosts file
    $remoteHostsFilePathMapped = "$driveName\hosts"
    Write-Host "Reading remote hosts file from $remoteHostsFilePathMapped..."
    try {
        $remoteHostsFileContent = Get-Content -Path $remoteHostsFilePathMapped -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to read remote hosts file. Error: $_" -ForegroundColor Red
        Remove-PSDrive -Name $driveName -Force
        return
    }

    # Check if the entry already exists in the remote hosts file
    if ($remoteHostsFileContent -notcontains $hostEntry) {
        Write-Host "Updating remote hosts file..."
        try {
            # Add the new entry to the remote hosts file
            Add-Content -Path $remoteHostsFilePathMapped -Value $hostEntry -ErrorAction Stop
            Write-Host "Hosts file updated on remote machine."
        }
        catch {
            Write-Host "Failed to update remote hosts file. Error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Host entry already exists in the remote hosts file."
    }

    # Remove the mapped drive
    Remove-PSDrive -Name $driveName -Force
}

# Example usage of the function
Update-RemoteHostsFile
