# Enhanced Error Handling for Hyper-V VM Creation

## Overview
The script now includes improved error handling for missing parent VHDX files, providing users with clear guidance and recovery options.

## Parent Disk Validation

### Primary OS Disk
When creating VMs with differencing disks, the script now:

1. **Early Validation**: Checks if the parent VHDX exists before attempting VM creation
2. **Clear Error Messages**: Provides specific error messages indicating the missing file location
3. **Recovery Options**: Offers three choices when parent disk is missing:
   - Enter a different parent VHDX path
   - Switch to standard (non-differencing) disk creation
   - Cancel VM creation

### Data Disk (Dual Disk Feature)
For the optional second data disk:

1. **Interactive Mode**: Prompts to create the parent disk if missing
2. **Auto-Creation in Smart Defaults**: Automatically creates the parent disk when using `-UseSmartDefaults`
3. **Graceful Degradation**: If creation fails, the VM is still created with just the primary disk
4. **Warning Messages**: Clear warnings explain why the data disk was skipped
5. **Helpful Guidance**: Instructions on how to create the missing parent disk

## Error Messages

### Missing Primary Parent Disk
```
ERROR: Parent VHDX file not found!
Expected location: C:\VM\Setup\VHDX\Windows_10.vhdx

The parent VHDX is required for creating differencing disks.
Please ensure the file exists at the specified location or update your configuration.

Would you like to:
[1] Enter a different parent VHDX path
[2] Create a standard (non-differencing) disk instead
[3] Cancel VM creation
```

### Missing Data Disk Parent (Interactive Mode)
```
WARNING: Data disk parent not found: D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx
Would you like to create it now? (Y/N)
```

If you choose Yes, the script will:
- Create the directory if needed
- Create a 256GB dynamic VHDX
- Format it with NTFS
- Add a marker file
- Continue with dual disk VM creation

### Missing Data Disk Parent (Smart Defaults Mode)
When using `-UseSmartDefaults`, the script automatically:
```
Data disk parent not found. Creating it automatically...
Creating parent data disk...
Formatting parent disk...
Parent data disk created successfully!
```

## Benefits

1. **No More Cryptic Errors**: Users get clear, actionable error messages
2. **Graceful Recovery**: Options to continue with alternative configurations
3. **Prevents Partial VMs**: Failed VM creation attempts are cleaned up automatically
4. **Educational**: Error messages explain what went wrong and how to fix it

## Best Practices

1. **Verify Parent Disks**: Always ensure parent VHDX files exist before running the script
2. **Use Correct Paths**: Double-check paths in configuration files
3. **Create Data Disk Parents**: Run `Create-DataDiskParent.ps1` once to set up data disk parents

## Troubleshooting

### Common Issues

1. **Wrong Drive Letter**: Parent disk is on D: but config points to C:
   - Solution: Edit configuration when prompted or update config file

2. **Moved Parent Disk**: Parent disk was relocated
   - Solution: Use option [1] to enter the new path

3. **Corrupted Parent Disk**: Parent disk exists but is corrupted
   - Solution: Create a new parent disk or use standard disk option

### Creating Parent Disks

For OS parent disks:
- Convert from ISO using the ISO-to-VHDX conversion script
- Or create a new VM and sysprep it for use as a parent

For data disk parents:
```powershell
.\Create-DataDiskParent.ps1 -Path "D:\VM\Setup\VHDX\DataDiskParent_256GB.vhdx"
```

## Summary

The enhanced error handling makes the VM creation process more robust and user-friendly, turning potential failures into guided recovery scenarios.