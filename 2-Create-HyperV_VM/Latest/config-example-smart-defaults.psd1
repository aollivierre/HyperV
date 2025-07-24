@{
    # Example configuration using smart defaults
    # Only specify what you need - everything else will be handled automatically
    
    # Required: VM Name prefix
    VMNamePrefixFormat   = "{0:D3} - Test Smart Defaults"
    
    # Required: ISO for OS installation
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # Optional: Use existing VHDX as template (comment out for new disk)
    # VHDXPath           = "D:\VM\Setup\VHDX\Windows_10_22H2_July_29_2023__100GB_Dynamic_UEFI_2025-06-13.vhdx"
    
    # Smart defaults - use these special values:
    ProcessorCount       = 'All Cores'      # Will use all available CPU cores
    SwitchName          = 'Default Switch'  # Will select best available switch
    
    # Optional overrides (remove these to use smart defaults):
    # MemoryStartupBytes = "4GB"           # Otherwise calculates based on available RAM
    # VMPath             = "D:\VM"          # Otherwise uses drive with most space
    # Generation         = 2                # Defaults to 2 (UEFI)
}