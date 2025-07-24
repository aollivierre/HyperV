@{
    # VHDXPath             = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_July_04_2024-100GB-unattend-PFW-OOBE-tasks.VHDX"
    VHDXPath             = "D:\VM\Setup\VHDX\Windows_10_22H2_July_29_2023__100GB_Dynamic_UEFI_2025-06-13.vhdx"
    SwitchName           = "Default Switch"  # Smart default - will auto-select best available switch
    ParentVHDPath        = "D:\VM\Setup\VHDX\Windows_10_22H2_July_29_2023__100GB_Dynamic_UEFI_2025-06-13.vhdx"
    VMPath               = "D:\VM"
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    MemoryStartupBytes   = "1GB"
    MemoryMinimumBytes   = "1GB"
    MemoryMaximumBytes   = "16GB"
    Generation           = 2
    VMNamePrefixFormat   = "{0:D3} - ABC Lab - Win 10 migration to Windows 11"
    ProcessorCount       = "All Cores"  # Smart default - uses all logical processors (including hyperthreading)
}