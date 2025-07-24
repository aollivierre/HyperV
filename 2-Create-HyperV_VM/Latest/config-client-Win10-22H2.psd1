@{
    # VM Type - 'Standard' for new disk, 'Differencing' for differencing disk
    VMType               = "Differencing"  # Use differencing disk by default
    
    # Parent VHDX for differencing disk (optional - only used if creating differencing disk)
    ParentVHDXPath       = "D:\VM\Setup\VHDX\Windows_10_22H2_July_29_2023__100GB_Dynamic_UEFI_2025-06-13.vhdx"
    
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
    VMNamePrefixFormat   = "{0:D3} - ABC Lab - Win 10 migration to Windows 11"
    ProcessorCount       = "All Cores"  # Smart default - uses all logical processors (including hyperthreading)
    
    # Advanced options
    UseAllAvailableSwitches = $false  # Set to $true to add all available switches as NICs
    AutoStartVM          = $true      # Automatically start VM after creation
    AutoConnectVM        = $true      # Automatically open VM console after creation
}