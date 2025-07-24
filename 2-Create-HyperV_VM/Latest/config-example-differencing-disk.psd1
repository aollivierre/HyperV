@{
    # Example configuration for creating a VM with a DIFFERENCING disk
    
    # VM Type - Explicitly set to create a differencing disk
    VMType               = "Differencing"
    
    # Parent VHDX - Required for differencing disk
    ParentVHDXPath       = "D:\VM\Setup\VHDX\Win11_24H2_English_x64_Oct16_2024-100GB.VHDX"
    
    # VM Name
    VMNamePrefixFormat   = "{0:D3} - Example - Differencing Disk VM"
    
    # ISO for OS installation (optional for differencing disk)
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
}