Based on the technical details provided and analysis of similar Hyper-V routing issues documented in enterprise environments, this anomaly appears rooted in three key Windows networking behaviors interacting with Hyper-V's virtual switch architecture:

### 1. Interface Metric Precedence vs. Route Metrics
Windows prioritizes interface metrics over route-specific metrics when multiple paths exist ([8]). Despite your static route having metric 1, the host's *interface metric* for the SecondaryNetwork adapter likely has a higher effective value due to:
- Automatic metric calculation based on link speed (default for internal switches)
- Interface prioritization in the network stack

**Solution:**  
```powershell
# Force interface metric on SecondaryNetwork
Get-NetAdapter | Where-Object {$_.InterfaceDescription -match "SecondaryNetwork"} | Set-NetIPInterface -InterfaceMetric 1

# Explicitly set gateway metric for primary NIC
Get-NetAdapter | Where-Object {$_.Name -eq "PrimaryNIC"} | Set-NetIPInterface -InterfaceMetric 100
```

### 2. Hyper-V Virtual Switch ARP Isolation
Internal switches create isolated layer-2 domains. The host's vNIC attached to an internal switch acts as a separate endpoint rather than a bridge ([6]). This explains:
- Why VMs communicate directly (within virtual switch)
- Why host traffic leaks through physical gateway (host isn't participating in virtual switch ARP)

**Solution:**  
```powershell
# Enable MAC address spoofing on host's vNIC
Set-VMNetworkAdapter -ManagementOS -Name "SecondaryNetwork" -MacAddressSpoofing On

# Enable IP forwarding at host level
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters -Name IpEnableRouter -Value 1
Restart-Computer
```

### 3. Windows Network Location Awareness
The 198.18.0.0/15 range is part of IANA's Benchmarking range, which Windows may treat as external by default. This interacts with:
- Connection-specific DNS suffixes
- Network location type (Public vs Private)
- Implicit firewall rules

**Diagnostic Tools:**
```powershell
# Check effective network categorization
Get-NetConnectionProfile

# Monitor real-time routing decisions
netsh trace start scenario=NetConnection capture=yes
# Reproduce issue then
netsh trace stop
```

### Critical Findings from Traffic Analysis
The TTL expired messages indicate packets are traversing:
```
Host -> Bell Router (192.168.100.254) -> ISP Gateway (142.161.0.173)
```
This reveals the host is:
1. Failing ARP resolution for 198.18.1.1
2. Defaulting to primary NIC's gateway despite static route
3. Not recognizing the internal switch as a valid path

### Recommended Resolution Path
1. **Registry Overrides:**
   ```powershell
   # Disable automatic metrics
   Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "DisableDHCPMediaSense" -Value 1

   # Force strict route precedence
   Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "IgnorePushDefaultRoutes" -Value 1
   ```

2. **Virtual Switch Reconfiguration:**
   ```powershell
   # Recreate internal switch with ARP bridging
   Remove-VMSwitch -Name "SecondaryNetwork" -Force
   New-VMSwitch -Name "SecondaryNetwork" -SwitchType Internal -EnableEmbeddedTeaming $true
   ```

3. **Firewall Rule Audit:**
   ```powershell
   # Allow ICMPv4 on host interface
   New-NetFirewallRule -DisplayName "Allow Internal Switch ICMP" -Direction Inbound -InterfaceAlias "vEthernet (SecondaryNetwork)" -Protocol ICMPv4 -Action Allow
   ```

4. **Persistent Static ARP (Last Resort):**
   ```powershell
   # Add permanent ARP entry
   arp -s 198.18.1.1 
   ```

This combination addresses the core conflict between Windows' routing logic and Hyper-V's network virtualization layer. The solution forces explicit route adherence while maintaining proper layer-2 connectivity between host and VMs.
