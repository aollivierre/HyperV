@{
    # Minimal configuration - let smart defaults handle everything else
    
    # VM Name - this is the only thing you need to customize
    VMNamePrefixFormat = '{0:D3} - My VM'
    
    # Required: Path to ISO file for OS installation
    InstallMediaPath = 'D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso'
    
    # Optional: Specify VHDX template for differencing disk (comment out for new VHD)
    # VHDXPath = 'D:\VM\Setup\VHDX\Windows_10_22H2_July_29_2023__100GB_Dynamic_UEFI_2025-06-13.vhdx'
    
    # Everything else will use smart defaults:
    # - ProcessorCount: Will use "All Cores" (all available cores)
    # - Memory: Will calculate based on available system memory
    # - SwitchName: Will use "Default Switch" or best available switch
    # - VMPath: Will be created on drive with most free space
    # - Generation: Will default to 2 (modern UEFI)
    # - TPM: Will be enabled for Gen 2 VMs
    # - Dynamic Memory: Will be enabled
}