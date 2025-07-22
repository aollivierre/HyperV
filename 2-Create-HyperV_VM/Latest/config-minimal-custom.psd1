@{
    # Example with some custom values but still using smart defaults
    
    # Required
    VMNamePrefixFormat = '{0:D3} - Test - Ubuntu Server'
    InstallMediaPath = 'ubuntu-22.04.3-live-server-amd64.iso'
    
    # Custom settings (everything else is automatic)
    ProcessorCount = 4              # Specific core count
    MemoryStartupBytes = '2GB'      # Override smart memory
    Generation = 1                  # Use Gen 1 for Linux compatibility
    IncludeTPM = $false            # No TPM for Linux
    
    # These would be set automatically:
    # - SwitchName: Best available switch
    # - VMPath: Drive with most space + \VMs
    # - MemoryMinimumBytes: Smart default
    # - MemoryMaximumBytes: Smart default
    # - EnableDynamicMemory: true
}