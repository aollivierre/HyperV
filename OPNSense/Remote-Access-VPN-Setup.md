# Home Lab Remote Access VPN Setup Guide

## Network Overview

- **Home Network**: 192.168.100.x (Bell Router)
- **Lab Network**: 198.18.1.x (OPNsense)
- **Hyper-V Host WAN IP**: 192.168.100.103
- **OPNsense WAN IP**: 192.168.100.x
- **OPNsense LAN IP**: 198.18.1.1

## VPN Solution Architecture

This guide describes two complementary VPN solutions:

1. **IPsec/IKEv2 on OPNsense** - For corporate laptop access without software installation
2. **Headscale with Subnet Router** - For personal devices with superior connectivity

### Why Two Different Solutions?

| Requirement | Corporate Laptop | Personal Devices |
|-------------|-----------------|------------------|
| Key Constraint | Cannot install software | No restrictions |
| Best Solution | IPsec/IKEv2 (built-in Windows) | Headscale/Tailscale |
| Firewall Compatibility | May be blocked (UDP 500/4500) | Works everywhere |
| Performance | Good (80-100 Mbps) | Excellent (300+ Mbps) |
| Setup Complexity | Moderate | Low |

## 1. IPsec/IKEv2 Setup for Corporate Laptop

### Why IPsec/IKEv2?
- Uses Windows built-in VPN client (no software installation)
- System-wide VPN tunnel allows native RDP connections
- Strong security with AES-256 encryption
- Works on Windows 10/11 out of the box

### 1.1 OPNsense Configuration

#### Create Certificate Authority
1. Navigate to **System → Trust → Authorities**
2. Click the **+** button to add a new CA
3. Configure:
   - Descriptive name: "VPN-CA"
   - Method: Create an internal Certificate Authority
   - Key length: 2048 bit or higher
   - Lifetime: 3650 (10 years)
   - Complete Common Name and Country fields
4. Click **Save**

#### Create Server Certificate
1. Navigate to **System → Trust → Certificates**
2. Click **+** to add a server certificate
3. Configure:
   - Method: Create an internal Certificate
   - Descriptive name: "VPN-Server"
   - Certificate authority: Select your newly created CA
   - Type: Server Certificate
   - Key length: 2048 bit or higher
   - Lifetime: 3650
   - Complete the Common Name field
   - Add Alternative Name: Your public DNS name if available
4. Click **Save**

#### Configure Mobile Client Support
1. Navigate to **VPN → IPsec → Mobile Clients**
2. Enable IPsec Mobile Client support
3. Configure:
   - Virtual IPv4 Address Pool: 10.10.1.0/24 (an unused range)
   - Authentication method: EAP-MSCHAPv2 (username/password)
   - Certificate: Select your server certificate
   - Enabled: Yes
4. Click **Save**

#### Create User Account
1. Navigate to **System → Access → Users**
2. Add a user with a secure password

#### Configure Phase 1
1. Navigate to **VPN → IPsec → Tunnel Settings**
2. Add a new Phase 1 entry:
   - Key Exchange: IKEv2
   - Interface: WAN
   - Remote Gateway: Dynamic
   - Description: "Remote Access VPN"
   - Authentication: Certificate + EAP-MSCHAPv2
   - My Certificate: Your server certificate
   - Encryption: AES-256-GCM
   - Hash: SHA-384
   - DH Group: 20 (ECP384)
3. Click **Save**

#### Configure Phase 2
1. Navigate to Phase 2 section for your Phase 1 entry
2. Add a new Phase 2 entry:
   - Local Network: 198.18.1.0/24 (your lab network)
   - Remote Network: Dynamic
   - Description: "Allow Lab Access"
   - Encryption: AES-256-GCM
   - Hash: SHA-384
   - PFS Group: 20 (ECP384)
3. Click **Save**

#### Configure Firewall Rules
1. Navigate to **Firewall → Rules → WAN**
2. Add rules to allow IPsec traffic:
   - Action: Pass
   - Interface: WAN
   - Protocol: UDP
   - Source: Any
   - Destination: WAN address
   - Destination port: 500, 4500
   - Description: "Allow IPsec"
3. Navigate to **Firewall → Rules → IPsec**
4. Add a rule to allow VPN to LAN traffic:
   - Action: Pass
   - Interface: IPsec
   - Protocol: Any
   - Source: Any
   - Destination: 198.18.1.0/24
   - Description: "Allow VPN to Lab"

### 1.2 Bell Router Configuration
1. Log in to your Bell router
2. Navigate to **Advanced Settings → Port Forwarding**
3. Create two forwarding rules:
   - UDP port 500 → 192.168.100.x (OPNsense WAN IP)
   - UDP port 4500 → 192.168.100.x (OPNsense WAN IP)

### 1.3 Windows Client Setup
1. Go to **Settings → Network & Internet → VPN**
2. Click **Add a VPN connection**
3. Configure:
   - VPN provider: Windows (built-in)
   - Connection name: Home Lab
   - Server name or address: Your public IP or dynamic DNS name
   - VPN type: IKEv2
   - Type of sign-in info: Username and password
   - Username and Password: Enter credentials from OPNsense user
4. Click **Save**
5. Connect to the VPN
6. Test by accessing a device on the 198.18.1.x network via RDP

## 2. Headscale Setup for Personal Devices

### Why Headscale/Tailscale?
- Works from any network (corporate, hotel, coffee shop)
- No port forwarding needed
- Excellent connection reliability
- Mesh networking capability
- Efficient WireGuard protocol underneath
- Self-hosted solution for complete privacy

### 2.1 Headscale Server Setup

Set up the Headscale server in Docker:

```bash
# Create directories
mkdir -p ~/headscale/{config,data}
cd ~/headscale

# Create config file
cat > config/config.yaml << 'EOF'
server_url: http://localhost:8080
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 0.0.0.0:50443
private_key_path: /var/lib/headscale/private.key
noise:
  private_key_path: /var/lib/headscale/noise_private.key
database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite
ip_prefixes:
  - 100.64.0.0/10
derp:
  server:
    enabled: true
    region_id: 999
    region_code: "home"
    region_name: "Home Lab"
    stun_listen_addr: "0.0.0.0:3478"
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  headscale:
    container_name: headscale
    image: headscale/headscale:latest
    volumes:
      - ./config:/etc/headscale
      - ./data:/var/lib/headscale
    ports:
      - "8080:8080"
      - "41641:41641/udp"
    restart: unless-stopped
    command: serve
EOF

# Start Headscale
docker-compose up -d

# Create a user
docker exec -it headscale headscale users create homelab

# Create an auth key
docker exec -it headscale headscale --user homelab preauthkeys create --reusable --expiration 24h
```

### 2.2 Subnet Router Setup

Set up a Tailscale subnet router to expose your lab network:

```bash
# Create directories
mkdir -p ~/tailscale-router/data
cd ~/tailscale-router

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  tailscale:
    container_name: tailscale-router
    image: tailscale/tailscale:latest
    network_mode: "host"
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - ./data:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    environment:
      - TS_STATE_DIR=/var/lib/tailscale
      - TS_USERSPACE=false
      - TS_ROUTES=198.18.1.0/24
      - TS_EXTRA_ARGS=--login-server=http://HEADSCALE_IP:8080 --advertise-routes=198.18.1.0/24
    restart: unless-stopped
EOF

# Start the subnet router
docker-compose up -d

# Authenticate to Headscale
docker exec -it tailscale-router tailscale up --login-server=http://HEADSCALE_IP:8080

# Enable IP forwarding on Ubuntu host
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 2.3 Enable Subnet Routes in Headscale
```bash
# Get the machine ID
docker exec -it headscale headscale nodes list

# Enable routes for the subnet router
docker exec -it headscale headscale routes enable -i MACHINE_ID
```

### 2.4 Client Setup on Personal Devices

#### macOS
1. Install Tailscale from App Store or download from tailscale.com
2. Run in terminal:
   ```
   tailscale up --login-server=http://YOUR_PUBLIC_IP:8080
   ```
3. Enter the auth key when prompted

#### iOS/Android
1. Install Tailscale app from App Store/Play Store
2. Go to Settings > Login server and change to your Headscale server
3. Login using the auth key

## Troubleshooting

### IPsec/IKEv2 Issues
1. **Connection Failures**:
   - Check Bell router port forwarding
   - Verify corporate firewall isn't blocking UDP 500/4500
   - Check OPNsense IPsec logs (System → Log Files → IPsec)
   - Test from different networks (mobile hotspot, home)

2. **Authentication Issues**:
   - Verify username/password in OPNsense
   - Check certificate validity
   - Try regenerating certificates

### Headscale Issues
1. **Connection Problems**:
   - Check if Docker containers are running: `docker ps`
   - Verify logs: `docker logs headscale`
   - Test connectivity: `curl http://localhost:8080/health`

2. **Subnet Routing Issues**:
   - Verify routes are enabled in Headscale
   - Check IP forwarding is enabled on host
   - Verify no firewall rules blocking traffic
   - Test connectivity with ping/traceroute

## Performance Considerations

- **IPsec/IKEv2**: Expect 80-100 Mbps throughput, ~5-15ms added latency
- **Headscale/Tailscale**: Expect 200-400 Mbps throughput, variable latency depending on route

## Security Recommendations

1. **Update regularly**: Keep OPNsense and Docker containers updated
2. **Use strong passwords**: For all VPN accounts
3. **Enable 2FA where possible**: For additional security
4. **Consider IP restrictions**: Limit access from trusted IPs only
5. **Monitor logs**: Check for unauthorized access attempts
6. **Rotate auth keys**: For Headscale, regenerate keys periodically

## References
- [OPNsense IPsec Documentation](https://docs.opnsense.org/manual/how-tos/ipsec-road.html)
- [Headscale GitHub Repository](https://github.com/juanfont/headscale)
- [Tailscale Subnet Router Documentation](https://tailscale.com/kb/1019/subnets/)
