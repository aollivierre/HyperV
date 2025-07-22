# Smart Defaults Configuration Guide

## Overview
The enhanced Hyper-V VM creation script now supports intelligent defaults that minimize configuration requirements. You only need to specify what's unique to your VM - the script figures out everything else!

## Minimal Configuration Examples

### 1. Absolute Minimum Configuration
```powershell
@{
    VMNamePrefixFormat = '{0:D3} - Lab - Windows 11'
    InstallMediaPath = 'Windows11.iso'
}
```
That's it! The script will:
- Find the ISO on any available drive
- Select the drive with most free space for the VM
- Use all available CPU cores
- Calculate optimal memory allocation
- Find or create the best network switch
- Enable all modern features (Gen 2, TPM, Dynamic Memory)

### 2. Using Smart Keywords
```powershell
@{
    VMNamePrefixFormat = '{0:D3} - Dev - Test VM'
    InstallMediaPath = 'Windows.iso'
    ProcessorCount = 'All Cores'      # Uses all available cores
    SwitchName = 'Default Switch'     # Finds best available switch
}
```

### 3. Differencing Disk (Minimal)
```powershell
@{
    VMNamePrefixFormat = '{0:D3} - Dev - Quick Test'
    VHDXPath = 'Template.vhdx'        # Template can be on any drive
    VMType = 'Differencing'
}
```

## Smart Features

### Automatic Drive Selection
- Scans all drives for available space
- Selects drive with most free space (minimum 50GB)
- Creates standard folder structure:
  - `X:\VMs` - Main VM storage
  - `X:\VMs\Templates` - VHDX templates
  - `X:\VMs\ISOs` - ISO files
  - `X:\VMs\Exports` - VM exports
  - `X:\VMs\Checkpoints` - Snapshots

### Smart Resource Allocation

#### CPU Cores
- `'All Cores'` - Uses all physical cores
- `Number` - Specific core count
- `Not specified` - Uses half of available cores

#### Memory
Automatically calculated based on available RAM:
- **Minimum Mode**: 20% of free RAM (for tight resources)
- **Balanced Mode**: 30% startup, up to 70% maximum (default)
- **Maximum Mode**: 50% startup, up to 80% maximum

#### Network Switch
- `'Default Switch'` - Finds best available
- `'Default'` - Same as above
- `Not specified` - Uses Default Switch if available, or creates one
- `Specific name` - Uses the named switch

### Running with Smart Defaults

#### Interactive Mode (default)
```powershell
.\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1
```
- Shows system resources
- Displays selected drive with confirmation
- Shows final configuration summary

#### Automatic Mode
```powershell
.\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1 -UseSmartDefaults
```
- Skips all confirmations
- Uses best available options automatically

#### Force Specific Drive
```powershell
.\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1 -AutoSelectDrive
```
- Auto-selects drive without prompting
- Still shows other confirmations

## Configuration Parameters

### Required Parameters
- `VMNamePrefixFormat` - Template for VM naming
- `InstallMediaPath` OR `VHDXPath` - Source for VM creation

### Optional Parameters with Smart Defaults
| Parameter | Default | Smart Behavior |
|-----------|---------|----------------|
| ProcessorCount | Half of total cores | Accepts 'All Cores' |
| MemoryStartupBytes | 30% of free RAM | Auto-calculated |
| MemoryMinimumBytes | Based on mode | Auto-calculated |
| MemoryMaximumBytes | 70% of free RAM | Auto-calculated |
| SwitchName | 'Default Switch' | Finds/creates best |
| VMPath | X:\VMs | Best drive |
| Generation | 2 | Modern UEFI |
| EnableDynamicMemory | true | Optimal performance |
| IncludeTPM | true (Gen2) | Windows 11 ready |

## Tips for Minimal Configuration

1. **Let the script decide**: Don't specify paths unless you have specific requirements
2. **Use keywords**: 'All Cores', 'Default Switch' for smart selection
3. **Trust the defaults**: The script makes intelligent choices based on your system
4. **Override when needed**: You can still specify any parameter explicitly

## Example: From Complex to Simple

### Old Way (Everything Specified)
```powershell
@{
    VMNamePrefixFormat = '{0:D3} - Lab - Test'
    InstallMediaPath = 'D:\ISOs\Windows11.iso'
    VMPath = 'D:\VMs'
    ProcessorCount = 8
    MemoryStartupBytes = '4GB'
    MemoryMinimumBytes = '2GB'
    MemoryMaximumBytes = '8GB'
    SwitchName = 'External Network'
    Generation = 2
    EnableDynamicMemory = $true
    IncludeTPM = $true
}
```

### New Way (Minimal)
```powershell
@{
    VMNamePrefixFormat = '{0:D3} - Lab - Test'
    InstallMediaPath = 'Windows11.iso'
}
```

The script automatically:
- Finds Windows11.iso on any drive
- Creates VM on drive with most space
- Uses optimal CPU and memory settings
- Configures networking automatically
- Enables all modern features

## Troubleshooting

### Script can't find ISO
- Ensure ISO exists on at least one drive
- Use full path if ISO is in non-standard location

### Wrong drive selected
- Use interactive mode to choose different drive
- Specify VMPath explicitly to force specific drive

### Not enough resources
- Script automatically adjusts to available resources
- Override memory settings if needed

### Network issues
- Script creates switch if none exist
- Specify SwitchName for specific switch