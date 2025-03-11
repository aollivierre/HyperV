# Windows Routing Anomaly with Hyper-V and OPNsense: Expert Analysis

The routing behavior you're experiencing demonstrates a fascinating intersection of Windows networking, Hyper-V virtualization, and IP addressing standards. After analyzing your configuration and symptoms, I've identified several key factors that likely contribute to this counterintuitive routing scenario, with the special IP range being the most probable root cause.

## The Special Case of 198.18.0.0/15 Address Space

The primary factor causing your routing anomaly appears to be your choice of IP addressing. The 198.18.0.0/15 range (which includes 198.18.0.0 to 198.19.255.255) is not a standard private IP range but a special purpose address block defined in RFCs for benchmarking network equipment and simulations[5]. Windows operating systems likely have specific handling for this range that overrides normal routing behavior.

This special treatment would explain why:
- Your explicit static routes with low metrics are being ignored
- Traffic is being sent to your ISP instead of the local interface
- Changing to other subnets within the same special range didn't resolve the issue
- VMs don't exhibit the same behavior (they may process routing differently)

According to the information available, this address range is "supposed to be used in special cases for benchmarking, etc."[3], which means Windows might intentionally route it differently than standard private ranges like 10.0.0.0/8 or 192.168.0.0/16.

## Windows Routing Mechanism and Metric Handling

Windows routing mechanisms are designed to follow the longest prefix match first, then use metrics to break ties. In your case, even though you've created a specific route with metric 1, Windows appears to be overriding this based on the special nature of the IP range[4][17].

The Windows Automatic Metric feature assigns metrics based on link speed[4], but your manual configuration should override this. The fact that it doesn't suggests that special handling for the 198.18.0.0/15 range takes precedence over manual metric configurations.

## Hyper-V Network Virtualization Complexities

The interaction between Hyper-V's network virtualization layer and the Windows routing stack creates additional complexity. Several factors specific to Hyper-V might be contributing to your issue:

### Virtual Switch Characteristics

Hyper-V virtual switches operate at layer 2 (like physical switches) and don't perform routing functions[7]. This means routing decisions are left to the operating system. Your internal virtual switch setup is correct, but the OS routing behavior is overriding expected behavior.

### MAC Address Spoofing

You've correctly enabled MAC address spoofing, which is essential for OPNsense to function properly in Hyper-V[1]. This allows the router VM to override MAC addresses, which is particularly important for bridged configurations.

### Network Isolation Mechanisms

Hyper-V implements various network isolation mechanisms that could interact with routing decisions. For instance, the VMs might process routing differently because they're isolated from some of the host's networking stack behaviors[13].

## Identifying The Root Cause

The most compelling evidence points to the 198.18.0.0/15 range being the primary issue. This is strengthened by:

1. The fact that traffic is consistently routed to your ISP rather than locally
2. The consistent "TTL expired in transit" from an ISP router (142.161.0.173)
3. The inability to resolve this through standard routing table manipulations
4. The working connectivity between VMs on the same network

This behavior mirrors what networking professionals would expect when dealing with globally routable addresses - Windows identifies 198.18.x.x as a range that should route via the internet, despite local configuration suggesting otherwise.

## Solutions and Recommendations

### Primary Solution: Change the IP Addressing Scheme

The most direct solution is to change your OPNsense LAN network to use a standard private IP range[5]:
- 10.0.0.0/8 (10.0.0.0 to 10.255.255.255)
- 172.16.0.0/12 (172.16.0.0 to 172.31.255.255)
- 192.168.0.0/16 (192.168.0.0 to 192.168.255.255)

For example, configure OPNsense LAN as 10.99.99.1/24 and the host's SecondaryNetwork adapter as 10.99.99.2/24.

### Alternative Approaches

If changing the IP scheme isn't feasible, consider these alternatives:

1. **Network Binding Order Modification**: Adjust the priority of network interfaces in Windows to prioritize the internal network[15].

2. **Registry Modification**: Investigate if there are registry entries that handle routing for special IP ranges that could be modified.

3. **IPEnableRouter Setting**: Enable IP routing at the Windows level using the registry setting, although this is primarily for routing between networks rather than fixing direct connectivity[2]:
   ```
   Set-ItemProperty -Path HKLM:\system\CurrentControlSet\services\Tcpip\Parameters -Name IpEnableRouter -Value 1
   ```

4. **VPN/Tunnel Approach**: Create a separate tunnel between the host and OPNsense that uses standard private IP addresses.

## Diagnostic Tools for Further Investigation

To further troubleshoot this issue, consider using:

1. **Network Packet Capture**: Use Wireshark to capture traffic when attempting to connect to 198.18.1.1 to see exactly how packets are being handled and routed.

2. **Route Tracing with Logging**: Enable network route tracing with `netsh trace start capture=yes tracefile=c:\temp\nettrace.etl` to get detailed information about routing decisions.

3. **ARP Table Monitoring**: Monitor the ARP table to see if address resolution is happening correctly for the 198.18.1.1 address.

4. **Firewall Logging**: Enable detailed Windows Firewall logging to check if there's any filtering happening for this specific IP range[10].

## Theoretical Explanation

The fundamental issue appears to be that Windows treats 198.18.0.0/15 as a special-purpose globally routable range, causing it to disregard local routing configurations. This behavior is likely hardcoded deep in the Windows TCP/IP stack as part of its compliance with networking standards and RFCs.

The VM doesn't show this behavior possibly because the virtualized network stack doesn't implement the same special case handling, or because traffic from VMs is processed differently by the Hyper-V virtual switch environment.

This examination reveals how operating systems can implement subtle networking behaviors based on IP address standards that override explicit user configuration, creating counterintuitive routing scenarios that challenge our understanding of standard networking principles.