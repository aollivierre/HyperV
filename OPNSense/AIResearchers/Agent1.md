## Analysis of the Routing Anomaly in Hyper-V Environment

### Overview of the Issue

The problem involves a Hyper-V host (Lab-HV01) unable to communicate directly with the LAN interface of an OPNsense VM (085 - OPNsense - Firewall) at IP address `198.18.1.1`, despite having a direct route configured with a low metric. Other VMs on the same network can reach the OPNsense LAN interface without issues.

### Key Factors Contributing to the Anomaly

1. **Routing Metrics and Default Gateway Behavior**:
   - Windows assigns metrics to routes based on interface speed and other factors. A lower metric indicates a preferred route[1][8].
   - Despite setting a metric of 1 for the direct route to `198.18.1.0/24`, traffic from the host is routed through the default gateway (`192.168.100.254`), suggesting that Windows might be overriding the manually set metric or prioritizing the default gateway under certain conditions.

2. **Hyper-V Virtual Switch Behavior**:
   - Hyper-V uses virtual switches to manage network traffic between VMs and the host. An internal virtual switch is used for the `198.18.1.x` network[5].
   - The anomaly might be related to how Hyper-V handles routing between the host and VMs connected to internal switches, possibly due to limitations in routing between different virtual networks without explicit routing configuration[5].

3. **VM vs. Host Routing Differences**:
   - VMs can directly reach the OPNsense LAN interface, indicating that the issue is specific to the host's routing configuration or interaction with Hyper-V.
   - This difference suggests that the host's routing table or network stack is handling traffic differently than the VMs.

4. **Potential Interference from Security Features**:
   - Windows Firewall, IPsec policies, or other security features might be influencing routing decisions, although this is less likely given the direct route configuration[6].

### Diagnostic Tools and Potential Solutions

1. **Network Stack Analysis**:
   - Use tools like `netsh`, `route print`, and `tracert` to inspect routing tables and packet paths.
   - Enable detailed network logging to capture packet routing decisions.

2. **Hyper-V Configuration Review**:
   - Ensure that the internal virtual switch is correctly configured and that MAC spoofing is enabled.
   - Consider enabling routing on the Hyper-V host by setting `IPEnableRouter` to 1 in the registry, although this is more relevant for routing between different virtual networks[5].

3. **Security Feature Inspection**:
   - Temporarily disable Windows Firewall and other security features to rule out interference.

4. **Alternative Routing Configurations**:
   - Consider using a separate VM as a router between the host and OPNsense VM if direct routing cannot be resolved.

### Conclusion

The anomaly likely stems from how Windows handles routing metrics and interacts with Hyper-V's virtual networking. The host's inability to use the direct route despite a low metric suggests that Windows is prioritizing the default gateway under certain conditions. Further investigation with network diagnostic tools and potential adjustments to Hyper-V configurations or security settings may resolve the issue.

### Recommendations for Further Investigation

- **Inspect Network Logs**: Use tools like Wireshark to capture network traffic and analyze routing decisions.
- **Disable Automatic Metric**: Ensure that the automatic metric feature is disabled for the relevant interfaces to prevent Windows from overriding manually set metrics[8].
- **Check for Conflicting Routes**: Verify that there are no conflicting routes in the routing table that might be causing Windows to prefer the default gateway.
- **Test with Different Subnets**: Continue testing with different subnet ranges to rule out any subnet-specific issues.

