# DNS Configuration and Troubleshooting Guide for Hyper-V Domain Controller Setup

This guide documents the process of troubleshooting and configuring DNS settings for a Hyper-V Domain Controller setup. The steps below were executed on February 20, 2025.

## Initial Diagnostics

### 1. Check Current DNS Server Settings
```powershell
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | Format-Table -AutoSize
```
Initial results showed incorrect DNS settings:
- Primary DNS: 192.168.100.254
- Secondary DNS: 216.130.71.72

### 2. Network Configuration Check
```powershell
ipconfig /all
```
This revealed:
- Ethernet adapter with IP: 192.168.100.168
- vEthernet (nat) adapter with IP: 172.30.96.1
- Incorrect DNS server configuration

## DNS Configuration Fix

### 1. Update DNS Server Settings
```powershell
Set-DnsClientServerAddress -InterfaceIndex 8 -ServerAddresses "192.168.100.198","1.1.1.1"
```
This command set:
- Primary DNS: 192.168.100.198
- Secondary DNS: 1.1.1.1

### 2. Verify DNS Server Changes
```powershell
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | Format-Table -AutoSize
```
Confirmed new DNS settings were applied correctly.

## DNS Functionality Testing

### 1. Test DNS Server Connectivity
```powershell
Test-NetConnection -ComputerName 192.168.100.198 -Port 53
```
Result: Successful - DNS port is accessible

### 2. Test DNS Resolution
```powershell
Resolve-DnsName google.com -Server 192.168.100.198
```
Result: Successful - DNS resolution working properly

## Network Configuration Summary

### Current Network Settings
- Primary Network Adapter: Ethernet
- IP Address: 192.168.100.168
- Primary DNS: 192.168.100.198
- Secondary DNS: 1.1.1.1
- Network Mask: 255.255.255.0
- Default Gateway: 192.168.100.254

### Additional Network Adapter
- Adapter Name: vEthernet (nat)
- IP Address: 172.30.96.1
- DNS Server: 192.168.100.198

## Related Scripts

The following scripts are available in this directory for automated server configuration:

1. `1-Set-Static-IPV4-from-DHCP-Configs.ps1`
   - Purpose: Configure static IP address from DHCP settings

2. `2-Automated Server Core Preparation with Current Network Settings.ps1`
   - Purpose: Comprehensive server preparation script
   - Includes DNS configuration and testing
   - Network configuration management
   - Domain preparation steps

3. `3-Add Additional Domain Controller to Existing Domain.ps1`
   - Purpose: Domain Controller promotion script

4. `4-Remote Post DC Promotion Diagnostics.ps1`
   - Purpose: Post-promotion diagnostic checks

## Troubleshooting Tips

If DNS issues occur:

1. Verify DNS server accessibility:
```powershell
Test-NetConnection -ComputerName <DNS_Server_IP> -Port 53
```

2. Check DNS resolution:
```powershell
Resolve-DnsName google.com -Server <DNS_Server_IP>
```

3. View current DNS settings:
```powershell
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses }
```

4. Update DNS settings if needed:
```powershell
Set-DnsClientServerAddress -InterfaceIndex <Index> -ServerAddresses "<Primary_DNS>","<Secondary_DNS>"
```

## Notes

- Always ensure the primary DNS server (192.168.100.198) is accessible before making changes
- The secondary DNS (1.1.1.1) provides backup resolution if the primary DNS is unavailable
- Network adapter index numbers may vary; verify before running commands
- Run all commands with administrative privileges
