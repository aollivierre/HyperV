@{
    # Ultra-minimal configuration - maximum use of smart defaults
    
    # Only two required fields:
    VMNamePrefixFormat = "{0:D3} - My New VM"
    InstallMediaPath   = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # That's it! Everything else will be handled by smart defaults:
    # - All CPU cores will be used
    # - Memory will be calculated based on available RAM
    # - Best drive will be selected automatically
    # - Virtual switch will be selected automatically
    # - Generation 2 VM with TPM enabled
    # - Dynamic memory enabled
}