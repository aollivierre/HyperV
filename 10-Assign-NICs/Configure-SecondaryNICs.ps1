#requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures the secondary network adapters in Hyper-V VMs with static IPs in the 198.18.x.x range.

.DESCRIPTION
    This script uses PowerShell Direct to connect to each running Hyper-V VM and configure
    the second network adapter with a static IP address in the 198.18.x.x range.
    The script automatically determines the right adapter and assigns sequential IPs.

.NOTES
    File Name      : Configure-SecondaryNICs.ps1
    Prerequisite   : Hyper-V Module, Administrator rights, Guest VMs must have PowerShell Direct capability
    Created        : 2025-03-02

.EXAMPLE
    .\Configure-SecondaryNICs.ps1
#>

# Check if the Hyper-V module is available
if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
    Write-Error "The Hyper-V PowerShell module is not available. Please ensure Hyper-V is installed and you're running this on a Hyper-V host."
    exit 1
}

# Import the Hyper-V module
Import-Module Hyper-V

# Get running VMs with filter for specific VMs
$runningVMs = Get-VM | Where-Object {
    $_.State -eq 'Running' -and (
        $_.Name -like "*ABC Lab*" -or
        $_.Name -like "*Lab-VSCode04*" -or
        $_.Name -like "*MGMT 001*"
    )
}
if ($runningVMs.Count -eq 0) {
    Write-Warning "No running VMs found."
    exit 0
}

Write-Host "Found $($runningVMs.Count) running VM(s):" -ForegroundColor Green
$runningVMs | ForEach-Object { Write-Host " - $($_.Name)" }
Write-Host ""

# Set the base network information
$subnetBase = "198.18.1"
$startIP = 10  # Will assign IPs starting from 198.18.1.10
$subnetMask = "255.255.255.0"

# Display information about what's going to happen
Write-Host "Ready to configure secondary NICs in $($runningVMs.Count) VM(s) with:" -ForegroundColor Yellow
Write-Host " - IP addresses starting from $subnetBase.$startIP (incrementing for each VM)" -ForegroundColor Yellow
Write-Host " - Subnet mask: $subnetMask" -ForegroundColor Yellow
Write-Host " - No default gateway will be configured on these NICs" -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANT: This script uses PowerShell Direct to connect to VMs." -ForegroundColor Red
Write-Host "Requirements for this to work:" -ForegroundColor Red
Write-Host " - VMs must be running Windows with PowerShell" -ForegroundColor Red
Write-Host " - VMs must have Hyper-V Integration Services installed" -ForegroundColor Red
Write-Host " - You must have administrator credentials for each VM" -ForegroundColor Red
Write-Host ""

# Set default domain credentials
$defaultDomain = "abc"
$defaultUsername = "$defaultDomain\administrator"

# Get credentials
$credentials = $null
$useCredentials = Read-Host "Do you need to provide credentials to access the VMs? (Y/N)"
if ($useCredentials -eq 'Y' -or $useCredentials -eq 'y') {
    $credentials = Get-Credential -Message "Enter credentials for VM access (must work across all VMs)"
} else {
    $credentials = Get-Credential -UserName $defaultUsername -Message "Enter domain admin credentials"
}

$confirmation = Read-Host "Proceed with network configuration? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Operation cancelled."
    exit 0
}

# Results tracking
$results = @()
$currentIP = $startIP

# Configure each VM
foreach ($vm in $runningVMs) {
    $vmName = $vm.Name
    $ipAddress = "$subnetBase.$currentIP"
    
    Write-Host "`nConfiguring VM: $vmName with IP: $ipAddress..." -ForegroundColor Cyan
    
    try {
        # Create the script block to run in the VM
        $scriptBlock = {
            # Find the second network adapter (likely the one we just added)
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Sort-Object -Property MacAddress
            
            if ($adapters.Count -lt 2) {
                throw "Less than two network adapters found. Expected to find at least two adapters."
            }
            
            # Get the second adapter (assuming Hyper-V NIC ordering matches what we see)
            $secondAdapter = $adapters | Select-Object -Last 1
            
            Write-Host "  Found adapter: $($secondAdapter.Name) (Index: $($secondAdapter.ifIndex))"
            
            # Check if IP is already configured and remove ALL IP addresses from the adapter
            $existingConfig = Get-NetIPConfiguration -InterfaceIndex $secondAdapter.ifIndex -ErrorAction SilentlyContinue
            if ($existingConfig) {
                Write-Host "  Removing existing IP configuration..."
                Remove-NetIPAddress -InterfaceIndex $secondAdapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
            }
            
            # Wait a moment for the removal to complete
            Start-Sleep -Seconds 2
            
            # Configure the IP address
            Write-Host "  Setting IP address to $($using:ipAddress) with subnet mask $($using:subnetMask)..."
            $null = New-NetIPAddress -InterfaceIndex $secondAdapter.ifIndex -IPAddress $using:ipAddress -PrefixLength 24 -ErrorAction Stop
            
            # Disable DHCP on the adapter
            Write-Host "  Disabling DHCP on the adapter..."
            $null = Set-NetIPInterface -InterfaceIndex $secondAdapter.ifIndex -DHCP Disabled -ErrorAction Stop
            
            # Display the configuration
            $newConfig = Get-NetIPConfiguration -InterfaceIndex $secondAdapter.ifIndex
            return @{
                AdapterName = $secondAdapter.Name
                IPAddress = $using:ipAddress
                SubnetMask = $using:subnetMask
                Success = $true
            }
        }
        
        # Run the script in the VM with credentials
        $result = Invoke-Command -VMName $vmName -Credential $credentials -ScriptBlock $scriptBlock -ErrorAction Stop
        
        # Add results
        $results += [PSCustomObject]@{
            VMName = $vmName
            IPAddress = $ipAddress
            AdapterName = $result.AdapterName
            Status = "Success"
            Error = $null
        }
        
        Write-Host "Successfully configured $vmName with IP $ipAddress" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to configure $vmName" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        
        $results += [PSCustomObject]@{
            VMName = $vmName
            IPAddress = $ipAddress
            AdapterName = $null
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
    
    # Increment IP for next VM
    $currentIP++
}

# Display summary
Write-Host "`n=== Configuration Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# Save the configuration results to a CSV file for reference
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "VMNetworkConfiguration.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host "`nConfiguration results saved to: $csvPath" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Green
Write-Host "1. Verify connectivity to VMs using these new IPs"
Write-Host "2. When ready, change your router subnet to the new 198.18.x.x range"
Write-Host "3. After migration is complete, you can reconfigure or remove the original NICs"
