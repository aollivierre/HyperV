### Analysis of the Hyper-V Host Routing Anomaly with OPNsense VM

The described issue, where the Hyper-V host cannot communicate with the OPNsense LAN interface but other VMs on the same network can, is a complex networking anomaly. Below is an in-depth analysis of potential causes, mechanisms at play, and recommendations for resolution.

---

### **Key Observations and Symptoms**
1. **Routing Issue**:
   - The Hyper-V host routes traffic to 198.18.1.1 (OPNsense LAN) via the default gateway (192.168.100.254), ignoring the direct route through the SecondaryNetwork interface (198.18.1.2).
   - Other VMs on the same internal switch successfully route directly to 198.18.1.1.

2. **Traceroute Behavior**:
   - From the host: Traffic goes through the Bell router (192.168.100.254) and out to the internet before failing.
   - From a VM: Traffic takes a direct route to 198.18.1.1.

3. **Routing Table**:
   - The host has a correct route for 198.18.1.0/24 via the SecondaryNetwork adapter with a low metric.

4. **Firewall and Network Configuration**:
   - MAC spoofing is enabled.
   - Static routes and ARP entries have been added but do not resolve the issue.
   - No apparent misconfiguration in OPNsense firewall rules.

---

### **Possible Causes**

#### 1. Windows Routing Behavior
Windows routing can sometimes exhibit unexpected behavior due to its reliance on metrics and automatic configurations:
- **Automatic Metric Feature**: Windows may override manually set metrics based on link speed or other factors, even if a lower metric is explicitly configured for a route[9].
- **Default Gateway Preference**: If multiple interfaces are present, Windows often prioritizes routes through the default gateway, especially when asymmetric routing or overlapping IP address spaces are detected[9][2].

#### 2. Hyper-V Virtual Switch Limitations
The Hyper-V virtual switch operates independently of the host's network stack:
- The host's network interface (vEthernet) and VMs' virtual NICs are treated as separate entities[13]. This independence can lead to scenarios where traffic originating from the host does not follow the same path as traffic from VMs.
- Internal switches rely on Layer 2 communication within their broadcast domain, but routing issues can arise if ARP resolution fails or if there are conflicts in MAC address handling[3][5].

#### 3. Interaction Between Host and VM Networks
- The Hyper-V host's inability to communicate with OPNsense's LAN interface could stem from how Hyper-V handles traffic between its own interfaces and internal switches.
- If OPNsense generates new MAC addresses for its bridged interfaces, and MAC spoofing is not fully functional or recognized by Hyper-V, this could disrupt communication[3].

#### 4. Special Treatment of IP Ranges
- The IP range 198.18.x.x is reserved for benchmarking and testing per RFC 2544, which might cause unexpected behavior in some network stacks or devices[7]. However, this is unlikely unless specific configurations or security policies are in place.

---

### **Diagnostic Tools and Techniques**

To better understand what is happening at the network stack level:
1. **Packet Capture**:
   - Use Wireshark or Microsoft Message Analyzer on both the host and OPNsense to trace ICMP packets and verify whether they are being sent/received correctly.
   
2. **Route Diagnostics**:
   - Use `route print` to confirm that the route to 198.18.1.x via SecondaryNetwork is correctly listed and has a lower metric than other routes.
   - Disable "Automatic Metric" for all interfaces and manually configure metrics to ensure proper prioritization[9].

3. **ARP Table Inspection**:
   - Check ARP tables on both the host (`arp -a`) and OPNsense to ensure MAC-to-IP mappings are correct.

4. **Windows Firewall Logs**:
   - Enable logging in Windows Firewall to check if traffic to 198.18.x.x is being blocked or redirected.

5. **Hyper-V Switch Logs**:
   - Review logs or enable port mirroring on the internal switch to monitor traffic flow between the host and OPNsense.

---

### **Potential Solutions**

#### **Routing Adjustments**
- Ensure that no default gateway is configured on the SecondaryNetwork adapter (198.18.x.x). Having multiple default gateways can cause improper routing behavior[9].
- Explicitly add a static persistent route using:
  ```powershell
  route add 198.18.1.0 mask 255.255.255.0 198.18.1.2 metric 1
  ```
- Verify that "Automatic Metric" is disabled for all interfaces[9].

#### **Hyper-V Configuration**
- Enable "MAC Address Spoofing" for all virtual adapters connected to OPNsense[3].
- Verify that no conflicting settings like "Router Guard" or "DHCP Guard" are enabled on virtual adapters[14].

#### **Firewall Rules**
- Temporarily disable Windows Firewall on the host to rule out interference with ICMP or other protocols.
- Ensure OPNsense LAN rules allow traffic from 198.18.x.x/24 without restrictions.

#### **Alternative Subnet Testing**
- Test with an alternative private subnet (e.g., 10.x.x.x) to rule out issues related to reserved IP ranges like 198.18.x.x[7].

#### **Registry Modification for Routing**
Enable IP routing on the Windows host by modifying the registry:
```powershell
Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters -Name IpEnableRouter -Value 1
Restart-Computer
```
This ensures that Windows routes traffic between its interfaces properly[6].

---

### **Underlying Networking Principles**

The issue highlights several key principles in Windows networking and Hyper-V environments:
1. Windows prioritizes routes based on metrics but may override manual settings due to automatic configurations like link speed detection.
2. Hyper-V separates host networking from VM networking, which can lead to discrepancies in routing behavior.
3. Reserved IP ranges like 198.18.x.x may trigger special handling in some systems.
4. Proper configuration of virtual switches, including features like MAC spoofing, is critical for seamless communication between hosts and VMs.

---

### Conclusion

The anomaly likely stems from a combination of Windows routing behavior and Hyper-V virtual switch mechanics, potentially exacerbated by reserved IP ranges or incomplete MAC spoofing functionality in OPNsense's configuration within Hyper-V.

By systematically applying diagnostic tools and implementing suggested solutions (e.g., static routes, disabling automatic metrics, enabling MAC spoofing), you should be able to resolve this issue while gaining deeper insight into how Hyper-V manages networking across its virtualized environment.

