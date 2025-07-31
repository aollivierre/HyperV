@{
    VHDXPath             = "D:\VM\Setup\ISO\ubuntu-24.04.2-desktop-amd64.iso"
    # SwitchName           = "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"
    # ParentVHDPath        = "D:\VM\Setup\VHDX\Windows_SERVER_2025_EVAL_x64FRE_en-us-May-17-2024-100GB.VHDX"
    VMPath               = "E:\VM"
    InstallMediaPath     = "D:\VM\Setup\ISO\ubuntu-24.04.2-desktop-amd64.iso"
    MemoryStartupBytes   = "4GB"
    MemoryMinimumBytes   = "4GB"
    MemoryMaximumBytes   = "16GB"
    Generation           = 2
    VMNamePrefixFormat   = "{0:D3} - Ubuntu - Claude Code - 01"
    ProcessorCount       = 24
    
    # Network configuration
    UseAllAvailableSwitches = $true  # Add all available switches as NICs
    
    # Data Disk Configuration (NEW FEATURE - Optional second disk)
    EnableDataDisk       = $false     # Set to $true to create a second disk for data
    DataDiskType         = "Standard"  # "Standard" or "Differencing"
    DataDiskSize         = 256GB      # Size for standard data disk
    DataDiskParentPath   = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"  # Parent for differencing data disk (not used when Type=Standard)
}