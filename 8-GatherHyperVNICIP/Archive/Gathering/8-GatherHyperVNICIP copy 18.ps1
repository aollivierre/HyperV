# Define the output file paths relative to the script's root directory
$outputCsvFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.csv"
$outputTxtFile = Join-Path -Path $PSScriptRoot -ChildPath "VM_Hosts_IPs.txt"

# Prompt the user to include IPv6 addresses
$includeIPv6 = Read-Host "Would you like to include IPv6 addresses? (yes/no)"
$includeIPv6 = $includeIPv6 -eq "yes"

# Initialize a list to store the VM details
$vmDetails = [System.Collections.Generic.List[PSCustomObject]]::new()
$hostsFileLines = [System.Collections.Generic.List[string]]::new()

# Function to get all VM DNS names and their IDs
function Get-AllVMDNSName {
    $WMIVMs = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_KvpExchangeComponent
    $VMDNShostnameData = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($WMIVM in $WMIVMs) {
        $VMDNSname = ($WMIVM.GuestIntrinsicExchangeItems | ConvertFrom-StringData)[1].Values
        $VMDNSname = (($VMDNSname -split ">")[5] -split "<")[0]
        
        $VMDNSAuditData = [pscustomobject]@{
            VMid    = $WMIVM.SystemName
            DNSName = $VMDNSname
        }
        $VMDNShostnameData.Add($VMDNSAuditData)
    }

    return $VMDNShostnameData
}

# Get all VM DNS names and their IDs
$VMDNSNames = Get-AllVMDNSName

# Get all VMs on the Hyper-V server
$vms = Get-VM

# Iterate through each VM and gather its name, host name, and IP address
foreach ($vm in $vms) {
    $vmName = $vm.Name
    $vmId = $vm.VMId

    # Find the DNS name corresponding to the VM ID
    $foundVM = $VMDNSNames | Where-Object { $_.VMid -eq $vmId }
    $vmHostName = $foundVM.DNSName

    # Retrieve the IP addresses of the VM
    $vmNetworkAdapters = Get-VMNetworkAdapter -VMName $vmName
    $vmIPAddresses = $vmNetworkAdapters | Select-Object -ExpandProperty IPAddresses

    foreach ($ip in $vmIPAddresses) {
        $isIPv6 = $ip.Contains(":")
        if ($null -ne $ip -and $ip -ne "" -and ($includeIPv6 -or -not $isIPv6)) {
            $vmDetails.Add([pscustomobject]@{
                HostName  = $vmHostName
                VMName    = $vmName
                IPAddress = $ip
            })
            $hostsFileLines.Add("$ip $vmHostName # VM Name: $vmName")
        }
    }
}

# Export the VM details to a CSV file
$vmDetails | Export-Csv -Path $outputCsvFile -NoTypeInformation

# Export the VM details to a text file in hosts file format
$hostsFileLines | Out-File -FilePath $outputTxtFile -Encoding utf8

# Display the VM details in GridView
$vmDetails | Out-GridView -Title "VM Host Names and IP Addresses"

# Output the VM details to the console
$vmDetails | Format-Table -AutoSize

# Output the hosts file content to the console
Get-Content -Path $outputTxtFile | Write-Output

# Open the text file using VS Code
Start-Process "code" -ArgumentList $outputTxtFile

# Output a message indicating the completion of the export
Write-Host "VM host names and IP addresses have been exported to $outputCsvFile and $outputTxtFile" -ForegroundColor Green

























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

# Example usage of the main function
Upload-RemoteHostsFileViaSCP














###############################################################################################################
###############################################################################################################
###############################################################################################################
###############################################################################################################
###############################################################################################################


###########Now we gathered the IPs for our VMs from Hyper-V we will update our Hosts file using VS Code and SSH

###############################################################################################################
###############################################################################################################
###############################################################################################################
###############################################################################################################
###############################################################################################################
###############################################################################################################
###############################################################################################################
###############################################################################################################
###############################################################################################################










function Start-SshAgent {
    try {
        Write-Host "Starting ssh-agent service if not already running."
        Start-Service ssh-agent
    } catch {
        Write-Host "Error starting ssh-agent service: $_"
    }
}

function Add-PrivateKeyToSshAgent {
    param (
        [string]$privateKeyPath
    )
    try {
        Write-Host "Adding private key to ssh-agent."
        ssh-add $privateKeyPath
    } catch {
        Write-Host "Error adding private key to ssh-agent: $_"
    }
}

function Ensure-SshConfigFile {
    param (
        [string]$sshConfigPath
    )
    try {
        if (Test-Path -Path $sshConfigPath) {
            Write-Host "Clearing the existing SSH config file content."
            Clear-Content -Path $sshConfigPath
        } else {
            Write-Host "SSH config file does not exist, creating a new one."
            New-Item -ItemType File -Path $sshConfigPath -Force
        }
    } catch {
        Write-Host "Error ensuring SSH config file: $_"
    }
}

function Add-RemoteHostToSshConfig {
    param (
        [string]$hostName,
        [string]$userName,
        [string]$hostAddress,
        [string]$sshConfigPath
    )
    try {
        Write-Host "Adding remote host details to SSH config file."
        $newHostEntry = @"
Host $hostName
    HostName $hostAddress
    User $userName
    IdentityFile $env:USERPROFILE\.ssh\id_rsa
    ForwardAgent yes
"@

        Add-Content -Path $sshConfigPath -Value $newHostEntry
        Write-Host "SSH config updated successfully with new host: $hostName."
    } catch {
        Write-Host "Error updating SSH config: $_"
    }
}

function Open-VSCodeAndConnect {
    param (
        [string]$hostName,
        [string]$remoteFilePath
    )
    try {
        Write-Host "Opening VS Code and SSH into the remote host: $hostName."
        code --remote ssh-remote+$hostName $remoteFilePath
    } catch {
        Write-Host "Error opening VS Code and connecting via SSH: $_"
    }
}

# Variables
$remoteHostName = "NNOTT-LLW-SL08"
$remoteUserName = "share"
$remoteHostAddress = "NNOTT-LLW-SL08"
$privateKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
$sshConfigPath = "$env:USERPROFILE\.ssh\config"
$remoteFilePath = "c:\Windows\System32\drivers\etc"  # WSL path format for Windows files

# Start the ssh-agent service
# Start-SshAgent

# Add private key to ssh-agent
Add-PrivateKeyToSshAgent -privateKeyPath $privateKeyPath

# Ensure SSH config file is ready
Ensure-SshConfigFile -sshConfigPath $sshConfigPath

# Add the remote machine details to SSH config
Add-RemoteHostToSshConfig -hostName $remoteHostName -userName $remoteUserName -hostAddress $remoteHostAddress -sshConfigPath $sshConfigPath

# Open VS Code and connect to the remote machine, then open the hosts file
Open-VSCodeAndConnect -hostName $remoteHostName -remoteFilePath $remoteFilePath











