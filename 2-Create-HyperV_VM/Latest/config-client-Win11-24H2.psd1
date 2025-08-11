@{
    # VM Type - 'Standard' for new disk, 'Differencing' for differencing disk
    VMType               = "Differencing"  # Use differencing disk by default
    
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
    VMNamePrefixFormat   = "{0:D3} - XYZ Lab - SetupLab01"
    ProcessorCount       = "All Cores"  # Smart default - uses all logical processors (including hyperthreading)
    
    # Advanced options
    UseAllAvailableSwitches = $true  # Set to $true to add all available switches as NICs
    AutoStartVM          = $true      # Automatically start VM after creation
    AutoConnectVM        = $true      # Automatically open VM console after creation
    
    # Data Disk Configuration (NEW FEATURE - Optional second disk)
    EnableDataDisk       = $false     # Set to $true to create a second disk for data
    DataDiskType         = "Differencing"  # "Standard" or "Differencing"
    DataDiskSize         = 256GB      # Size for standard data disk (ignored for differencing)
    DataDiskParentPath   = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"  # Parent for differencing data disk
}