# Windows Hyper-V Routing Anomaly Analysis

Your networking issue demonstrates an interesting conflict between Windows routing behavior and Hyper-V networking. Let me explain what's likely happening and provide potential solutions.

## Root Cause Analysis

The primary issue appears to be related to Windows' routing decision process overriding your explicit routing configuration:

1. **Windows Routing Metric Behavior**: Windows doesn't always honor routing table entries even with low metrics[1]. When you have multiple interfaces and routes, Windows sometimes overrides user-defined metrics based on its own prioritization logic[2].

2. **IP Routing Interference**: The Windows IP routing capability may be interfering with the direct communication path. When Windows has IP routing enabled (`IPEnableRouter=1`), it can cause unexpected routing behaviors, particularly with virtual networks[9].

3. **Virtual Switch Architecture**: Hyper-V's internal virtual switch architecture creates a separate networking stack that sometimes doesn't integrate seamlessly with the host's routing table[7]. Even when you've correctly configured the SecondaryNetwork adapter on the host with 198.18.1.2/24, Windows may still prefer routing through the physical adapter based on its internal routing logic.

## Specific Technical Explanation

The "TTL expired in transit" error and traceroute results indicate that Windows is making a routing decision that ignores the direct route to 198.18.1.0/24 via your internal adapter, instead preferring the default gateway. This happens because:

1. **Automatic Metric Feature**: Windows uses an "Automatic Metric" feature that configures route metrics based on link speed[10]. Even with manually configured metrics, this can sometimes override user preferences.

2. **Interface Binding Order**: Windows may be prioritizing the physical adapter in its binding order, causing traffic to prefer that path regardless of metrics[3].

3. **Possible IPsec Policy Interference**: Windows may have active IPsec policies that affect inter-VLAN/subnet routing[12][15]. These policies can cause certain traffic to be redirected in ways that aren't obvious from the routing table.

## Recommended Solutions

Based on the technical analysis, here are specific solutions to try:

### 1. Disable IP Routing on the Host

If you don't need IP routing functionality on the host itself:

```
Set-ItemProperty -Path HKLM:\system\CurrentControlSet\Services\Tcpip\Parameters -Name IpEnableRouter -Value 0
Restart-Computer
```

This prevents Windows from attempting to route between interfaces, which can interfere with Hyper-V's virtual networking[9].

### 2. Reconfigure Interface Metrics and Binding Order

Disable automatic metric assignment and manually set metrics:
- Open network adapter properties → IPv4 properties → Advanced → IP Settings tab
- Uncheck "Automatic metric" and set the SecondaryNetwork adapter to metric 1[10]
- Set your primary network adapter to a higher metric (e.g., 100)

### 3. Check for Interfering Windows Features

Examine and potentially disable these features temporarily:
- Windows Firewall's connection security rules/IPsec policies[15]
- Routing and Remote Access Service (if installed)[9]
- IP routing features enabled through Windows Features

### 4. Alternative Virtual Switch Configuration

Instead of using an Internal switch, try:
- Create a Private virtual switch and connect only VMs to it
- Configure a dedicated router VM that has interfaces on both networks[7]
- Enable MAC address spoofing for all virtual adapters connected to the switch[4]

### 5. Network Registry Tweaks

Try this registry modification to force Windows to prioritize more specific routes:
```
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "EnableDeadGWDetect" -Value 0 -PropertyType DWORD -Force
```

### 6. Diagnostic Commands

Run these commands to help diagnose the routing issue:
```
Get-NetIPInterface | Select InterfaceAlias, InterfaceIndex, AddressFamily, AutomaticMetric, InterfaceMetric | Sort InterfaceMetric
Get-NetRoute -DestinationPrefix 198.18.1.0/24 | Format-List *
netsh interface ipv4 show interfaces
```

## Why VMs Work but Host Doesn't

The VM can communicate directly with 198.18.1.1 while the host can't because:

1. The VM's networking stack is isolated and simplified compared to the host's
2. VMs don't have the same complex routing behavior that Windows Server implements on physical hosts
3. Windows treats virtual adapters created for the host differently than those created for VMs[13]

This is a known anomaly in Hyper-V networking where the host routing behavior doesn't match VM routing behavior even with identical configurations[6][11].

If none of the above solutions work, you might need to add that IP alias on OPNsense in the 192.168.100.x range as you mentioned, or configure a dedicated routing VM that bridges between the networks properly.
