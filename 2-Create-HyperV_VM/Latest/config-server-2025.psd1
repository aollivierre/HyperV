@{
    # VM Type - 'Standard' for new disk, 'Differencing' for differencing disk
    VMType               = "Standard"  # Create new disk for server
    
    # Parent VHDX for differencing disk (required if VMType = 'Differencing')
    ParentVHDXPath       = "D:\VM\Setup\VHDX\WinServer2025_English_x64_July_24_2025-100GB.vhdx"
    
    # Network and paths
    SwitchName           = "Default Switch"  # Smart default - will auto-select best available switch
    VMPath               = "D:\VM"
    InstallMediaPath     = "D:\VM\Setup\ISO\Windows_SERVER_2025_EVAL_x64FRE_en-us-July-25-2025.iso"
    
    # Memory configuration
    MemoryStartupBytes   = "4GB"
    MemoryMinimumBytes   = "4GB"
    MemoryMaximumBytes   = "16GB"
    
    # VM settings
    Generation           = 2
    VMNamePrefixFormat   = "{0:D3} - ABC LAB - Testing ISO to VHDX converter"
    ProcessorCount       = "All Cores"  # Smart default - uses all logical processors
    
    # Advanced options
    UseAllAvailableSwitches = $false  # Set to $true to add all available switches as NICs
    AutoStartVM          = $false     # Do not auto-start server VMs
    AutoConnectVM        = $false     # Do not auto-connect to server VMs
}
