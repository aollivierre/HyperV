@{
    # Example configuration for creating a VM with dual disks (OS + Data)
    
    # VM Name
    VMNamePrefixFormat   = "{0:D3} - Example - Dual Disk VM"
    
    # Primary OS Disk Configuration
    VMType               = "Differencing"
    ParentVHDXPath       = "D:\VM\Setup\VHDX\Win11_24H2_English_x64_Oct16_2024-100GB.VHDX"
    
    # Data Disk Configuration (NEW FEATURE)
    EnableDataDisk       = $true                    # Enable second disk for data
    DataDiskType         = "Differencing"           # "Standard" or "Differencing"
    DataDiskSize         = 256GB                    # Size for standard data disk
    DataDiskParentPath   = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"  # Parent for differencing data disk
    
    # ISO for OS installation (optional for differencing disk)
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # Smart defaults
    ProcessorCount       = "All Cores"
    SwitchName          = "Default Switch"
    
    # Memory configuration
    MemoryStartupBytes   = "4GB"
    MemoryMinimumBytes   = "2GB"
    MemoryMaximumBytes   = "16GB"
    
    # Advanced options
    UseAllAvailableSwitches = $false
    AutoStartVM          = $true
    AutoConnectVM        = $true
}