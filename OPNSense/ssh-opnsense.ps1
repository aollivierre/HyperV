# Simple script to SSH into OPNsense with password
# This uses the plink utility which comes with PuTTY

param(
    [string]$Target = "lan", # "lan" or "wan"
    [string]$Command = ""    # Optional command to run
)

# Set variables based on target
if ($Target -eq "lan") {
    $host_ip = "198.18.1.1"
} elseif ($Target -eq "wan") {
    $host_ip = "192.168.100.137"
} else {
    $host_ip = $Target # In case an IP is directly provided
}

$username = "root"
$password = "opnsense"

# Create command
if ($Command -eq "") {
    # Interactive session
    $cmd = "echo $password | ssh $username@$host_ip"
} else {
    # Run specific command
    $cmd = "echo $password | ssh $username@$host_ip '$Command'"
}

# Execute
Write-Host "Connecting to OPNsense at $host_ip..."
Invoke-Expression $cmd
