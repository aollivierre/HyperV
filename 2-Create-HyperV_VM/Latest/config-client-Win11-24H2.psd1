@{
    # VM Type - Optional: 'Standard' for new disk, 'Differencing' for differencing disk
    # If not specified, user will be prompted or smart defaults will decide
    # VMType             = "Differencing"
    
    # Parent VHDX for differencing disk (optional - only used if creating differencing disk)
    ParentVHDXPath       = "D:\VM\Setup\VHDX\Win11_24H2_English_x64_Oct16_2024-100GB.VHDX"
    
    # Network and paths
    SwitchName           = "Default Switch"  # Smart default - will auto-select best available switch
    VMPath               = "D:\VM"
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # Memory configuration
    MemoryStartupBytes   = "1GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "16GB"
    
    # VM settings
    Generation           = 2
    VMNamePrefixFormat   = "{0:D3} - ABC - TDD - AB - Unit - Integration - Testing - 01"
    ProcessorCount       = "All Cores"  # Smart default - uses all logical processors (including hyperthreading)
}