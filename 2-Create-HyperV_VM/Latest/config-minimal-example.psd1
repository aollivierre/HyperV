@{
    # Minimal configuration - just specify what's unique to this VM
    
    # Required: VM naming pattern
    VMNamePrefixFormat = '{0:D3} - Lab - Windows 11'
    
    # Required: ISO path for installation
    InstallMediaPath = 'Windows11.iso'  # Will use smart drive selection
    
    # Optional: Use special values for smart defaults
    ProcessorCount = 'All Cores'     # Uses all available CPU cores
    SwitchName = 'Default Switch'    # Uses best available switch
    
    # Everything else uses smart defaults:
    # - Memory: Automatically calculated based on available RAM
    # - Paths: Created on drive with most free space
    # - Generation: 2 (modern UEFI)
    # - TPM: Enabled for Gen 2 VMs
    # - Dynamic Memory: Enabled
}