@{
    VHDXPath           = "E:\VM\Setup\VHDX\SERVER_Core-2022_Feb_01_EVAL_x64FRE_en-us-100GB.VHDX"
    SwitchName         = "Intel(R) Ethernet Connection (5) I219-LM - Virtual Switch"
    ParentVHDPath      = "E:\VM\Setup\VHDX\SERVER_Core-2022_Feb_01_EVAL_x64FRE_en-us-100GB.VHDX"
    VMPath             = "E:\VM"
    InstallMediaPath   = "E:\VM\Setup\ISO\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024.iso"
    MemoryStartupBytes = "4GB"
    MemoryMinimumBytes = "4GB"
    MemoryMaximumBytes = "16GB"
    Generation         = 2
    # VMNamePrefixFormat = "{0:D3} - MGMT 001 - PS - WAC - SM - RSAT - Desktop Exp"
    VMNamePrefixFormat = "{0:D3} - CCI-DC02"
    ProcessorCount     = 28
}