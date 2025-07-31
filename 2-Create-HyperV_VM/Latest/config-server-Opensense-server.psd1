@{
    # OPNsense VM Configuration
    VHDXPath             = "D:\VM\Setup\VHDX\OPNsense-25.1-Base.vhdx"
    VMPath               = "D:\VM"
    InstallMediaPath     = "D:\VM\Setup\ISO\OPNsense-25.1-dvd-amd64.iso"
    MemoryStartupBytes   = "4GB"
    MemoryMinimumBytes   = "2GB"
    MemoryMaximumBytes   = "8GB"
    Generation           = 2
    VMNamePrefixFormat   = "{0:D3} - OPNsense - Firewall"
    ProcessorCount       = 2
    SecureBoot           = $false # Explicitly set secure boot to disabled for OPNsense compatibility
    
    # Network configuration - OPNsense needs multiple NICs for firewall
    SwitchName           = "Default Switch"  # WAN interface
    UseAllAvailableSwitches = $true  # Automatically add all available switches (for LAN interfaces)
    
    # Alternatively, you can specify specific switches:
    # ExternalSwitchName = "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"  # WAN
    # InternalSwitchName = "OPNsense-LAN-Private"  # LAN
}