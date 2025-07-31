@{
    # TEST CONFIG - Multi-NIC Enabled
    VMType               = "Standard"
    
    # Network - MULTI-NIC ENABLED
    SwitchName           = "Default Switch"
    UseAllAvailableSwitches = $true  # This enables multi-NIC
    
    # Basic settings  
    VMNamePrefixFormat   = "{0:D3} - TEST - MultiNIC Validation"
    VMPath               = "D:\VM"
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # Memory
    MemoryStartupBytes   = "2GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "4GB"
    
    # Other settings
    Generation           = 2
    ProcessorCount       = 2
    AutoStartVM          = $false
    AutoConnectVM        = $false
}