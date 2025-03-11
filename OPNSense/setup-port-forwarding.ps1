# PowerShell script to set up port forwarding on OPNsense
# This script will SSH to OPNsense and create/run the port forwarding script

# OPNsense connection details
$OPNsense_IP = "198.18.1.1"
$OPNsense_User = "root"

Write-Host "Setting up RDP port forwarding on OPNsense..." -ForegroundColor Green
Write-Host "Connecting to $OPNsense_IP as $OPNsense_User..." -ForegroundColor Yellow
Write-Host "You will be prompted for the OPNsense password." -ForegroundColor Yellow

# Create the remote script content
$remoteScript = @'
#!/bin/sh

# Script to setup RDP port forwarding rules in OPNsense
# This script adds firewall rules for RDP access to lab VMs
# For use with OPNsense 21.x and higher
# Created for Hyper-V lab setup

# Configuration - Modify these values as needed
OPNSENSE_WAN_IP="192.168.100.137"
VM1_IP="198.18.1.10"
VM2_IP="198.18.1.11"
RDP_PORT="3389"
VM1_EXTERNAL_PORT="33891"
VM2_EXTERNAL_PORT="33892"

# Function to check if a rule already exists
rule_exists() {
  local port="$1"
  pfctl -s nat | grep -q "$port"
  return $?
}

# Add port forwarding rules
echo "Adding NAT port forwarding rules..."

# VM1 port forwarding
if ! rule_exists "$VM1_EXTERNAL_PORT"; then
  echo "Adding port forwarding for VM1 ($VM1_IP:$RDP_PORT via port $VM1_EXTERNAL_PORT)"
  echo "nat on em0 inet from any to $OPNSENSE_WAN_IP port $VM1_EXTERNAL_PORT -> $VM1_IP port $RDP_PORT" | pfctl -a rdp/forward -f -
  echo "pass in quick on em0 inet proto tcp from any to $OPNSENSE_WAN_IP port $VM1_EXTERNAL_PORT flags S/SA keep state" | pfctl -a rdp/pass -f -
else
  echo "Port forwarding rule for $VM1_EXTERNAL_PORT already exists, skipping."
fi

# VM2 port forwarding
if ! rule_exists "$VM2_EXTERNAL_PORT"; then
  echo "Adding port forwarding for VM2 ($VM2_IP:$RDP_PORT via port $VM2_EXTERNAL_PORT)"
  echo "nat on em0 inet from any to $OPNSENSE_WAN_IP port $VM2_EXTERNAL_PORT -> $VM2_IP port $RDP_PORT" | pfctl -a rdp/forward -f -
  echo "pass in quick on em0 inet proto tcp from any to $OPNSENSE_WAN_IP port $VM2_EXTERNAL_PORT flags S/SA keep state" | pfctl -a rdp/pass -f -
else
  echo "Port forwarding rule for $VM2_EXTERNAL_PORT already exists, skipping."
fi

# Make the rules persistent by creating a startup script
echo "Creating startup script for persistence..."
mkdir -p /usr/local/etc/rc.d

cat > /usr/local/etc/rc.d/custom_rdp_forward.sh << EOF
#!/bin/sh

# Custom script to add RDP forwarding rules at system startup
# This file is automatically created by setup-port-forwarding.sh

# Add VM1 port forward
pfctl -a rdp/forward -F all 2>/dev/null || true
pfctl -a rdp/pass -F all 2>/dev/null || true

echo "nat on em0 inet from any to $OPNSENSE_WAN_IP port $VM1_EXTERNAL_PORT -> $VM1_IP port $RDP_PORT" | pfctl -a rdp/forward -f -
echo "pass in quick on em0 inet proto tcp from any to $OPNSENSE_WAN_IP port $VM1_EXTERNAL_PORT flags S/SA keep state" | pfctl -a rdp/pass -f -

echo "nat on em0 inet from any to $OPNSENSE_WAN_IP port $VM2_EXTERNAL_PORT -> $VM2_IP port $RDP_PORT" | pfctl -a rdp/forward -f -
echo "pass in quick on em0 inet proto tcp from any to $OPNSENSE_WAN_IP port $VM2_EXTERNAL_PORT flags S/SA keep state" | pfctl -a rdp/pass -f -
EOF

chmod +x /usr/local/etc/rc.d/custom_rdp_forward.sh

# Verify the rules were added
echo ""
echo "==== NAT RULES ===="
pfctl -a rdp/forward -s nat
echo ""
echo "==== FILTER RULES ===="
pfctl -a rdp/pass -s rules
echo ""

echo "Configuration completed successfully."
echo ""
echo "Your RDP forwarding is now configured:"
echo "- To access VM1 ($VM1_IP): RDP to $OPNSENSE_WAN_IP:$VM1_EXTERNAL_PORT"
echo "- To access VM2 ($VM2_IP): RDP to $OPNSENSE_WAN_IP:$VM2_EXTERNAL_PORT"
echo ""
echo "These settings will persist across reboots."
'@

# Save the script to a temporary file
$tempFile = [System.IO.Path]::GetTempFileName()
$remoteScript | Out-File -FilePath $tempFile -Encoding ascii

# Now SSH to OPNsense and upload/execute the script
Write-Host "Uploading port forwarding script to OPNsense..." -ForegroundColor Yellow

# Execute the commands
# ssh $OPNsense_User@$OPNsense_IP "cat > /tmp/setup_rdp_access.sh" < $tempFile
ssh $OPNsense_User@$OPNsense_IP "chmod +x /tmp/setup_rdp_access.sh && /tmp/setup_rdp_access.sh"

# Clean up
Remove-Item $tempFile

Write-Host "Port forwarding setup completed!" -ForegroundColor Green
