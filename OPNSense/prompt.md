Expert Analysis Request: Hyper-V Host Routing Anomaly with OPNsense VM
Technical Environment
I'm experiencing a peculiar routing issue in my Hyper-V environment that defies standard networking logic. Here are the specifics:

Setup
Host: Windows Server with Hyper-V (Lab-HV01)
Router: Bell Home Hub 3000 (192.168.100.254)
VM: OPNsense firewall (085 - OPNsense - Firewall)
Virtual Switches:
WAN: External switch "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"
LAN: Internal switch "SecondaryNetwork"
Network Configuration
Host Primary NIC: 192.168.100.103/24 (connected to Bell router)
Host SecondaryNetwork: 198.18.1.2/24 (for OPNsense LAN)
OPNsense WAN: DHCP from Bell router
OPNsense LAN: 198.18.1.1/24
Test VM (Lab-VSCode04): Has adapters on both 192.168.100.x and 198.18.1.x networks
The Issue
The Hyper-V host cannot communicate with OPNsense's LAN interface (198.18.1.1), but other VMs on the same network can.

Detailed Symptoms
Pinging 198.18.1.1 from the Hyper-V host results in "TTL expired in transit" responses from 142.161.0.173 (an ISP router)
Traceroute from host shows all traffic to 198.18.1.1 routing through 192.168.100.254 (Bell router) and out to the internet
Lab-VSCode04 VM successfully pings 198.18.1.1 with a direct route (1 hop)
The host's SecondaryNetwork adapter has 198.18.1.2/24 configured correctly
The virtual switch is Internal type with MAC spoofing enabled
What I've Tried
Static Routes: Added explicit routes to 198.18.1.0/24 via the SecondaryNetwork adapter with metric 1
Interface Metrics: Set the lowest possible interface metric (1) for SecondaryNetwork
ARP Manipulation: Added static ARP entries mapping 198.18.1.1 to OPNsense's MAC address
Switch Configuration: Verified switch type (Internal), enabled MAC address spoofing
Guard Features: Disabled Router Guard and DHCP Guard on the VM adapters
Alternative Subnets: Tested multiple subnet ranges (172.20.1.x, 172.33.1.x, 192.169.1.x, 10.99.99.x) - all exhibit the same behavior
Restarting Services: Restarted Hyper-V services and network adapters
Validation Tests
Traceroute comparisons:
From VM: 1 hop direct to 198.18.1.1
From host: Routes through 192.168.100.254 -> ISP routers -> TTL expired
Route table: Host has correct route for 198.18.1.0/24 via SecondaryNetwork adapter with metric 1
Direct connection attempt: Failed even with low-level socket connection
Questions for Analysis
What mechanisms in Windows/Hyper-V networking would cause traffic to ignore a direct route with metric 1 and instead follow the default gateway?
Why would a VM on the same host successfully route directly to 198.18.1.1 while the host itself cannot?
Could there be some interaction between the Hyper-V Virtual Switch and Windows routing that creates this anomaly?
Is there a known Windows networking behavior that would cause specific IP ranges (like 198.18.x.x) to be treated differently in routing decisions?
What low-level diagnostic tools could reveal what's happening at the network stack level when Windows makes this routing decision?
Are there any specific Hyper-V or Windows network settings that might override normal routing metrics in this scenario?
Could there be any interaction with Windows Firewall, IPsec policies, or other security features causing this behavior?
I'm seeking a technical explanation of why this is occurring and potential solutions beyond the workaround of adding an IP alias to OPNsense in the 192.168.100.x range. The goal is to understand the underlying networking principles that explain this counterintuitive behavior.