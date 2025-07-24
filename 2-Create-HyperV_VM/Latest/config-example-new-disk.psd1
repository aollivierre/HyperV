@{
    # Example configuration for creating a VM with a NEW disk
    
    # VM Type - Explicitly set to create a new disk
    VMType               = "Standard"
    
    # VM Name
    VMNamePrefixFormat   = "{0:D3} - Example - New Disk VM"
    
    # ISO for OS installation
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # Smart defaults
    ProcessorCount       = "All Cores"
    SwitchName          = "Default Switch"
    
    # Memory configuration
    MemoryStartupBytes   = "2GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "8GB"
    
    # Advanced options
    UseAllAvailableSwitches = $false  # Set to $true to add all available switches as NICs
    AutoStartVM          = $true      # Automatically start VM after creation
    AutoConnectVM        = $true      # Automatically open VM console after creation
    
    # Note: No ParentVHDXPath needed for new disk creation
}