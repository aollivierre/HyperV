@{
    # VM Type - 'Standard' for new disk, 'Differencing' for differencing disk
    VMType               = "Differencing"  # Create new disk for server
    
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
    UseAllAvailableSwitches = $true  # Set to $true to add all available switches as NICs
    AutoStartVM          = $true     # Do not auto-start server VMs
    AutoConnectVM        = $true     # Do not auto-connect to server VMs
    
    # Data Disk Configuration (NEW FEATURE - Optional second disk)
    EnableDataDisk       = $false     # Set to $true to create a second disk for data
    DataDiskType         = "Differencing"  # "Standard" or "Differencing"
    DataDiskSize         = 256GB      # Size for standard data disk (ignored for differencing)
    DataDiskParentPath   = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"  # Parent for differencing data disk
}
