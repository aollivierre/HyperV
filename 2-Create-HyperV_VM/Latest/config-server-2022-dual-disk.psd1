@{
    # Windows Server 2022 with dual disk configuration
    
    # Primary OS Disk - Using differencing disk from parent
    VHDXPath           = "D:\VM\Setup\VHDX\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024-100GB.VHDX"
    ParentVHDPath      = "D:\VM\Setup\VHDX\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024-100GB.VHDX"
    
    # Data Disk Configuration (NEW FEATURE)
    EnableDataDisk     = $true
    DataDiskType       = "Differencing"
    DataDiskSize       = 256GB  # Used only if DataDiskType = "Standard"
    DataDiskParentPath = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"
    
    # VM paths and media
    VMPath             = "D:\VM"
    InstallMediaPath   = "D:\VM\Setup\ISO\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024.iso"
    
    # VM resources
    MemoryStartupBytes = "4GB"
    MemoryMinimumBytes = "4GB"
    MemoryMaximumBytes = "16GB"
    Generation         = 2
    ProcessorCount     = 24
    
    # VM naming
    VMNamePrefixFormat = "{0:D3} - Server 2022 - Dual Disk"
}