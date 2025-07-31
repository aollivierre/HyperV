@{
    # Quick VM Configuration - Maximum use of smart defaults
    # Only customize what you need!
    
    # VM Name - Customize this for your VM
    VMNamePrefixFormat   = "{0:D3} - Quick Test VM"
    
    # ISO Path - Required for OS installation
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # Everything else uses smart defaults:
    ProcessorCount       = "All Cores"     # Uses all logical processors (including hyperthreading)
    SwitchName          = "Default Switch" # Auto-selects best available switch
    
    # Optional: Uncomment to use existing VHDX as template
    # VHDXPath          = "D:\VM\Setup\VHDX\Windows_11_Template.vhdx"
    
    # All other settings (memory, paths, generation, etc.) will be auto-configured
    
    # Network configuration
    UseAllAvailableSwitches = $true  # Add all available switches as NICs
    
    # Data Disk Configuration (NEW FEATURE - Optional second disk)
    EnableDataDisk       = $false     # Set to $true to create a second disk for data
    DataDiskType         = "Differencing"  # "Standard" or "Differencing"
    DataDiskSize         = 256GB      # Size for standard data disk (ignored for differencing)
    DataDiskParentPath   = "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"  # Parent for differencing data disk
}