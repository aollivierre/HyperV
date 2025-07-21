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
}