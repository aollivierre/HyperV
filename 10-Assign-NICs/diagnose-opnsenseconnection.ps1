# OPNsense Network Diagnostic and Fix Script
# Run as Administrator

function Write-Status {
    param (
        [string]$Message,
        [string]$Status = "Info",
        [int]$IndentLevel = 0
    )
    
    $indent = "    " * $IndentLevel
    $color = switch ($Status) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Info" { "Cyan" }
        "Action" { "Magenta" }
        default { "White" }
    }
    
    Write-Host "$indent$Message" -ForegroundColor $color
}

# 1. Check VM Status
Write-Status "STEP 1: Checking OPNsense VM Status" -Status "Info"
$vmName = "085 - OPNsense - Firewall"
$vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Status "VM '$vmName' not found. Please check the VM name." -Status "Error" -IndentLevel 1
    Write-Status "Available VMs:" -Status "Info" -IndentLevel 1
    Get-VM | ForEach-Object { Write-Status "- $($_.Name)" -IndentLevel 2 }
    exit
}

if ($vm.State -ne "Running") {
    Write-Status "VM '$vmName' is not running (current state: $($vm.State))" -Status "Warning" -IndentLevel 1
    Write-Status "Starting VM '$vmName'..." -Status "Action" -IndentLevel 1
    Start-VM -Name $vmName
    Write-Status "Waiting 30 seconds for VM to boot..." -Status "Info" -IndentLevel 1
    Start-Sleep -Seconds 30
    $vm = Get-VM -Name $vmName
}

Write-Status "VM '$vmName' is running" -Status "Success" -IndentLevel 1

# 2. Check VM Network Configuration
Write-Status "`nSTEP 2: Checking VM Network Configuration" -Status "Info"
$vmNetAdapters = Get-VMNetworkAdapter -VMName $vmName
$lanAdapter = $vmNetAdapters | Where-Object { $_.Name -eq "LAN" -or $_.SwitchName -like "*Secondary*" }
$wanAdapter = $vmNetAdapters | Where-Object { $_.Name -eq "WAN" -or $_.SwitchName -like "*External*" -or $_.SwitchName -like "*Realtek*" }

if (-not $lanAdapter) {
    Write-Status "LAN adapter not found on VM" -Status "Error" -IndentLevel 1
} else {
    Write-Status "LAN adapter connected to: $($lanAdapter.SwitchName)" -Status "Success" -IndentLevel 1
}

if (-not $wanAdapter) {
    Write-Status "WAN adapter not found on VM" -Status "Error" -IndentLevel 1
} else {
    Write-Status "WAN adapter connected to: $($wanAdapter.SwitchName)" -Status "Success" -IndentLevel 1
}

# 3. Check Host Network Configuration
Write-Status "`nSTEP 3: Checking Host Network Configuration" -Status "Info"
$secondaryAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*SecondaryNetwork*" }

if (-not $secondaryAdapter) {
    Write-Status "Secondary Network adapter not found on host" -Status "Error" -IndentLevel 1
    exit
}

Write-Status "Found SecondaryNetwork adapter (Index: $($secondaryAdapter.ifIndex))" -Status "Success" -IndentLevel 1

$ipConfig = Get-NetIPAddress -InterfaceIndex $secondaryAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
if (-not $ipConfig -or $ipConfig.IPAddress -like "169.254.*") {
    Write-Status "SecondaryNetwork has APIPA address or no IP configuration" -Status "Warning" -IndentLevel 1
    Write-Status "Re-configuring static IP address..." -Status "Action" -IndentLevel 1
    
    # Remove existing IP configuration
    Remove-NetIPAddress -InterfaceIndex $secondaryAdapter.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    
    # Add static IP address
    $null = New-NetIPAddress -InterfaceIndex $secondaryAdapter.ifIndex -IPAddress "198.18.1.2" -PrefixLength 24
    
    Write-Status "Waiting for IP configuration to apply..." -Status "Info" -IndentLevel 1
    Start-Sleep -Seconds 5
    
    # Restart network adapter
    Write-Status "Restarting network adapter..." -Status "Action" -IndentLevel 1
    Restart-NetAdapter -Name $secondaryAdapter.Name
    Start-Sleep -Seconds 5
} else {
    Write-Status "SecondaryNetwork has IP: $($ipConfig.IPAddress)/$($ipConfig.PrefixLength)" -Status "Success" -IndentLevel 1
    Write-Status "Address State: $($ipConfig.AddressState)" -Status "Info" -IndentLevel 1
    
    if ($ipConfig.AddressState -ne "Preferred") {
        Write-Status "IP address not in Preferred state. Restarting adapter..." -Status "Action" -IndentLevel 1
        Restart-NetAdapter -Name $secondaryAdapter.Name
        Start-Sleep -Seconds 5
    }
}

# 4. Test Network Connectivity
Write-Status "`nSTEP 4: Testing Network Connectivity" -Status "Info"
$pingResult = Test-Connection -ComputerName "198.18.1.1" -Count 4 -Quiet
if ($pingResult) {
    Write-Status "Successfully pinged OPNsense at 198.18.1.1" -Status "Success" -IndentLevel 1
} else {
    Write-Status "Could not ping OPNsense at 198.18.1.1" -Status "Warning" -IndentLevel 1
    Write-Status "Trying to fix network configuration..." -Status "Action" -IndentLevel 1
    
    # Try alternative approaches to fix connectivity
    Write-Status "Checking route table..." -Status "Info" -IndentLevel 1
    $routes = Get-NetRoute -DestinationPrefix "198.18.1.0/24" -ErrorAction SilentlyContinue
    
    if (-not $routes) {
        Write-Status "Adding route to 198.18.1.0/24 network..." -Status "Action" -IndentLevel 1
        New-NetRoute -DestinationPrefix "198.18.1.0/24" -InterfaceIndex $secondaryAdapter.ifIndex -NextHop "0.0.0.0"
    }
    
    # Check if Windows Firewall is blocking ICMP
    Write-Status "Checking Windows Firewall settings..." -Status "Info" -IndentLevel 1
    $fwRules = Get-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -ErrorAction SilentlyContinue
    
    if ($fwRules -and $fwRules.Enabled -eq $false) {
        Write-Status "Enabling ICMP Echo Request in Windows Firewall..." -Status "Action" -IndentLevel 1
        Enable-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)"
    }
    
    # Try one more ping
    Write-Status "Testing connectivity again..." -Status "Info" -IndentLevel 1
    $pingResult = Test-Connection -ComputerName "198.18.1.1" -Count 2 -Quiet
    if ($pingResult) {
        Write-Status "Successfully pinged OPNsense at 198.18.1.1 after fixes" -Status "Success" -IndentLevel 1
    } else {
        Write-Status "Still unable to ping OPNsense at 198.18.1.1" -Status "Error" -IndentLevel 1
        Write-Status "Please verify OPNsense is configured with IP 198.18.1.1 on LAN interface" -Status "Info" -IndentLevel 1
    }
}

# 5. Test HTTP/HTTPS Connectivity
Write-Status "`nSTEP 5: Testing Web Access" -Status "Info"
$webTestResult = $false

try {
    # Bypass SSL certificate validation
    add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Try to access the web UI
    $webRequest = [System.Net.WebRequest]::Create("https://198.18.1.1")
    $webRequest.Timeout = 5000
    $webResponse = $webRequest.GetResponse()
    $webTestResult = $true
    $webResponse.Close()
} catch {
    Write-Status "Error accessing OPNsense web UI: $_" -Status "Warning" -IndentLevel 1
}

if ($webTestResult) {
    Write-Status "Successfully accessed OPNsense web UI at https://198.18.1.1" -Status "Success" -IndentLevel 1
} else {
    Write-Status "Could not access OPNsense web UI" -Status "Warning" -IndentLevel 1
    Write-Status "Try accessing https://198.18.1.1 manually in your browser" -Status "Info" -IndentLevel 1
    Write-Status "Remember to accept any certificate warnings" -Status "Info" -IndentLevel 1
}

# 6. Summary
Write-Status "`nSUMMARY:" -Status "Info"
Write-Status "VM Status: Running" -Status "Success" -IndentLevel 1
Write-Status "Network Adapter Configuration:" -Status "Success" -IndentLevel 1
Write-Status "- Host SecondaryNetwork: $($secondaryAdapter.Name) [Index: $($secondaryAdapter.ifIndex)]" -Status "Info" -IndentLevel 2

$updatedIpConfig = Get-NetIPAddress -InterfaceIndex $secondaryAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($updatedIpConfig) {
    Write-Status "- IP Address: $($updatedIpConfig.IPAddress)/$($updatedIpConfig.PrefixLength) ($($updatedIpConfig.AddressState))" -Status "Info" -IndentLevel 2
}

Write-Status "Ping Test: $(if ($pingResult) {"Success"} else {"Failed"})" -Status $(if ($pingResult) {"Success"} else {"Warning"}) -IndentLevel 1
Write-Status "Web UI Test: $(if ($webTestResult) {"Success"} else {"Not Verified"})" -Status $(if ($webTestResult) {"Success"} else {"Warning"}) -IndentLevel 1

Write-Status "`nNEXT STEPS:" -Status "Info"
Write-Status "1. Try accessing https://198.18.1.1 in your browser" -Status "Info" -IndentLevel 1
Write-Status "2. Log in with username 'root' and password 'opnsense'" -Status "Info" -IndentLevel 1
Write-Status "3. Complete the OPNsense setup wizard" -Status "Info" -IndentLevel 1
Write-Status "4. Configure your devices to use the 198.18.1.x network" -Status "Info" -IndentLevel 1