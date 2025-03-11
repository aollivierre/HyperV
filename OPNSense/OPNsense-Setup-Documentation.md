# OPNsense Firewall Setup for Home Lab Documentation

## Overview

This document details the setup of OPNsense as a virtualized firewall for a home lab environment, specifically designed to avoid conflicts with corporate VPN connections. It documents the network architecture, challenges encountered, and solutions implemented.

## Network Architecture

### Physical Components
- **Internet Connection**: Bell Home Hub 3000 (192.168.100.254)
- **Hyper-V Host**: Lab-HV01 (192.168.100.103)
- **VMs**: Including Lab-VSCode04 and other lab machines

### Hyper-V Components
- **VM Name**: "085 - OPNsense - Firewall"
- **Virtual Switches**:
  - **WAN**: "Realtek Gaming 2.5GbE Family Controller - Virtual Switch" (External)
  - **LAN**: "SecondaryNetwork" (Internal)

### Network Addressing
- **Home Network**: 192.168.100.0/24 (Bell router)
- **Lab Network**: 198.18.1.0/24 (OPNsense managed)
  - OPNsense LAN IP: 198.18.1.1
  - DHCP Range: 198.18.1.100-198.18.1.200
  - Hyper-V Host Secondary IP: 198.18.1.2

## Objectives

1. Create an isolated network segment (198.18.1.0/24) for the home lab
2. Avoid conflicts with corporate VPN that routes all 192.168.x.x traffic
3. Allow internet access for lab VMs through OPNsense
4. Provide firewall protection for lab environment

## Implementation Steps

### 1. OPNsense VM Configuration
1. Created OPNsense VM in Hyper-V named "085 - OPNsense - Firewall"
2. Configured with 2 network adapters:
   - WAN connected to external switch
   - LAN connected to internal switch (SecondaryNetwork)

### 2. Network Configuration
1. Removed IP 198.18.1.1 from Hyper-V host to avoid conflict
2. Added IP 198.18.1.2 to host's SecondaryNetwork adapter
3. Configured OPNsense:
   - WAN: DHCP from Bell router
   - LAN: Static IP 198.18.1.1/24
   - DHCP server enabled for 198.18.1.100-198.18.1.200

### 3. VM Network Configuration
Configured lab VMs (e.g., Lab-VSCode04) with:
- Primary NIC: 192.168.100.x (Bell network)
- Secondary NIC: 198.18.1.x (OPNsense network)

## Challenges Encountered

### 1. VPN Routing Conflicts
Corporate VPN captures all traffic for standard private ranges:
- 10.0.0.0/8
- 172.16.0.0/12
- 192.168.0.0/16

Solution: Used 198.18.1.0/24 network (part of TEST-NET-2 reserved range) to avoid VPN conflicts.

### 2. IP Address Conflicts
Initial attempts to use 192.168.1.x for the lab network created conflicts when:
- Corporate VPN is connected (routes all 192.168.x.x)
- Bell router uses 192.168.100.x

Solution: Moved to 198.18.1.0/24 to avoid all conflicts.

### 3. Hyper-V Host Connectivity Issues
The Hyper-V host initially couldn’t directly access OPNsense at 198.18.1.1 despite:
- Host having 198.18.1.2 configured
- VM-to-VM communication working fine

#### Symptoms:
- Pings from host to 198.18.1.1 resulted in “TTL expired in transit” from 142.161.0.173
- Traceroute showed traffic routing through Bell router (192.168.100.254) instead of direct
- Lab VMs could ping and access OPNsense at 198.18.1.1 without issues

#### Attempted Solutions:
Various solutions were attempted but did not resolve the issue:
1. Static Routes
2. MAC Address Spoofing
3. Router/DHCP Guard settings
4. Static ARP entries
5. Switch type verification
6. Alternative subnet testing

#### Root Cause and Solution:
The actual issue was that the network interfaces in OPNsense were **physically swapped** - the WAN and LAN adapters were connected to the wrong vSwitches in Hyper-V. This was discovered by comparing MAC addresses from OPNsense console with the Hyper-V virtual NIC configurations. After correcting the interface assignments in OPNsense, the connectivity issue was resolved.

## Port Forwarding Configuration

### Overview
Port forwarding was attempted to enable RDP access to lab VMs while connected to corporate VPN, but has not been successful as of March 10, 2025.

### Implementation
- **Purpose**: Allow remote RDP access to lab VMs (198.18.1.x) from external network
- **Method**: NAT port forwarding using OPNsense web UI
- **Configuration**:
  - Virtual IP on WAN Interface: 192.168.100.200/24
  - VM1 (198.18.1.10): External port 33891 → Internal port 3389
  - VM2 (198.18.1.11): External port 33892 → Internal port 3389

### Configuration Steps
1. **Add Virtual IP** to OPNsense WAN interface (192.168.100.200/24)
2. **Create Port Forwarding Rules** in Firewall → NAT → Port Forward:
   - Interface: WAN
   - Protocol: TCP
   - Destination: 192.168.100.200/32
   - Destination port: 33891 (VM1) or 33892 (VM2)
   - Redirect target IP: 198.18.1.10 (VM1) or 198.18.1.11 (VM2)
   - Redirect target port: 3389
   - NAT reflection: Enabled

### Current Status
- **Not Working**: When attempting to connect from corporate laptop without VPN to the OPNsense WAN IP on the specified ports, error message appears stating “another connection was made by another PC”
- **Next Steps**: Further troubleshooting required, possibly involving:
  1. Checking for port conflicts
  2. Verifying firewall rules on both OPNsense and target VMs
  3. Testing different external ports
  4. Examining RDP server settings on target VMs

### Key Findings
1. **Virtual IP Usage**: Using a static virtual IP (192.168.100.200) provides a stable address for port forwarding regardless of DHCP changes
2. **Web UI Configuration**: Port forwarding rules are best created through the OPNsense web UI for visibility and persistence
3. **Subnet Selection**: Using 198.18.1.0/24 range for internal lab network prevents routing conflicts with corporate VPN
4. **Interface Verification**: Always verify that network interfaces are properly assigned to the correct vSwitches by comparing MAC addresses in both Hyper-V and OPNsense

### Troubleshooting
- If RDP connection fails, verify:
  - Port forwarding rules are correctly configured in OPNsense
  - Virtual IP is properly assigned to WAN interface
  - Corporate firewall/VPN allows outbound connections on the specified ports
  - Target VM’s firewall allows RDP connections
  - Target VM’s RDP service is running
  - No other services are using the same ports
  - RDP is configured to allow multiple connections on the target VMs

## Next Steps

1. Troubleshoot the port forwarding RDP connection issues
2. Test alternative port numbers for RDP forwarding
3. Consider additional firewall rules to improve security
4. Explore using an SSH tunnel as an alternative to direct RDP access

---

*Document updated: March 10, 2025*
