@{
    # VHDXPath           = "E:\VM\Setup\VHDX\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024_Standard_100GB_Dynamic_UEFI_2025-02-13.vhdx"
    VHDXPath           = "D:\VM\Setup\VHDX\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024-100GB.VHDX"
    # SwitchName         = "Realtek Gaming 2.5GbE Family Controller - Virtual Switch"
    # ParentVHDPath      = "E:\VM\Setup\VHDX\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024_Standard_100GB_Dynamic_UEFI_2025-02-13.vhdx"
    ParentVHDPath      = "D:\VM\Setup\VHDX\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024-100GB.VHDX"
    VMPath             = "D:\VM"
    InstallMediaPath   = "D:\VM\Setup\ISO\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024.iso"
    MemoryStartupBytes = "4GB"
    MemoryMinimumBytes = "4GB"
    MemoryMaximumBytes = "16GB"
    Generation         = 2
    # VMNamePrefixFormat = "{0:D3} - MGMT 001 - PS - WAC - SM - RSAT - Desktop Exp"
    VMNamePrefixFormat = "{0:D3} - XYZ Lab - DC1 - Server Desktop"
    ProcessorCount     = 24
    
    # Data Disk Configuration (NEW FEATURE - Optional second disk)
    EnableDataDisk       = $false     # Set to $true to create a second disk for data
    DataDiskType         = "Differencing"  # "Standard" or "Differencing"
    DataDiskSize         = 256GB      # Size for standard data disk (ignored for differencing)
    DataDiskParentPath   = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"  # Parent for differencing data disk
}