@{
    # Minimal configuration for differencing disk VM
    
    # Required: VM naming pattern
    VMNamePrefixFormat = '{0:D3} - Dev - Windows Server'
    
    # Required for differencing: Parent VHDX template
    VHDXPath = 'WindowsServer2022-Template.vhdx'  # Will find on best drive
    VMType = 'Differencing'
    
    # That's it! Everything else is automatic:
    # - ProcessorCount: Half of available cores
    # - Memory: Smart allocation based on available RAM
    # - Switch: Best available network switch
    # - Paths: Automatically created on best drive
}