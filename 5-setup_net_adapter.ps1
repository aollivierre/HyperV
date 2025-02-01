#v1

# $adapter = Get-NetAdapter -InterfaceAlias "Ethernet"

# $ipv4 = "66.244.227.222"
# $gateway = "66.244.227.217"
# $dns = "8.8.8.8", "8.8.4.4"

# $netProfile = Get-NetConnectionProfile -InterfaceAlias $adapter.InterfaceAlias

# Set-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -AddressFamily IPv4 -Dhcp Disabled -SkipDefaultGatewayCheck $true
# New-NetIPAddress -InterfaceAlias $adapter.InterfaceAlias -IPAddress $ipv4 -PrefixLength 24 -DefaultGateway $gateway
# Set-DnsClientServerAddress -InterfaceAlias $adapter.InterfaceAlias -ServerAddresses $dns
# Set-NetConnectionProfile -InterfaceAlias $adapter.InterfaceAlias -NetworkCategory Private
# Set-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -InterfaceMetric 5

# Set-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -Enabled $false
# Set-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip -Enabled $true




#v2
# $adapter = Get-NetAdapter -InterfaceAlias "Ethernet"; $ipv4 = "66.244.227.222"; $gateway = "66.244.227.217"; $dns = "8.8.8.8", "8.8.4.4"; $netProfile = Get-NetConnectionProfile -InterfaceAlias $adapter.InterfaceAlias; Set-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -AddressFamily IPv4 -Dhcp Disabled -SkipDefaultGatewayCheck $true; New-NetIPAddress -InterfaceAlias $adapter.InterfaceAlias -IPAddress $ipv4 -PrefixLength 24 -DefaultGateway $gateway; Set-DnsClientServerAddress -InterfaceAlias $adapter.InterfaceAlias -ServerAddresses $dns; Set-NetConnectionProfile -InterfaceAlias $adapter.InterfaceAlias -NetworkCategory Private; Set-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -InterfaceMetric 5; Set-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -Enabled $false; Set-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip -Enabled $true



#v3
# $adapter = Get-NetAdapter -InterfaceAlias "Ethernet"; $ipv4 = "66.244.227.222"; $subnetmask = "255.255.255.248"; $gateway = "66.244.227.217"; $dns = "8.8.8.8", "8.8.4.4"; $netProfile = Get-NetConnectionProfile -InterfaceAlias $adapter.InterfaceAlias; Set-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -AddressFamily IPv4 -Dhcp Disabled -SkipDefaultGatewayCheck $true; New-NetIPAddress -InterfaceAlias $adapter.InterfaceAlias -IPAddress $ipv4 -PrefixLength 29 -DefaultGateway $gateway; Set-DnsClientServerAddress -InterfaceAlias $adapter.InterfaceAlias -ServerAddresses $dns; Set-NetConnectionProfile -InterfaceAlias $adapter.InterfaceAlias -NetworkCategory Private; Set-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -InterfaceMetric 5; Set-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -Enabled $false; Set-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip -Enabled $true





#lastest version in oneline suitable to use for the clipboard paste method in a Hyper-V Virtual Machine

$adapter = Get-NetAdapter -InterfaceAlias "Ethernet"; $ipv4 = "66.244.227.222"; $subnetmask = "255.255.255.248"; $gateway = "66.244.227.217"; $dns = "8.8.8.8", "8.8.4.4"; $netProfile = Get-NetConnectionProfile -InterfaceAlias $adapter.InterfaceAlias; Set-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -AddressFamily IPv4 -Dhcp Disabled; New-NetIPAddress -InterfaceAlias $adapter.InterfaceAlias -IPAddress $ipv4 -PrefixLength 29 -DefaultGateway $gateway; Set-DnsClientServerAddress -InterfaceAlias $adapter.InterfaceAlias -ServerAddresses $dns; Set-NetConnectionProfile -InterfaceAlias $adapter.InterfaceAlias -NetworkCategory Private; Set-NetIPInterface -InterfaceAlias $adapter.InterfaceAlias -InterfaceMetric 5; Set-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip6 -Enabled $false; Set-NetAdapterBinding -Name $adapter.Name -ComponentID ms_tcpip -Enabled $true

