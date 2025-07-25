# Quick Start - ISO to VHDX Conversion

## For Windows Server 2025 Users

Use **`Create-VHDX-Working.ps1`** - This is the ONLY script that works reliably on Server 2025.

### Basic Usage

```powershell
# Run from this directory
.\Create-VHDX-Working.ps1
```

The script will:
1. Prompt for ISO path if not found
2. Show all Windows editions and let you choose
3. Create the VHDX in your specified directory

### Examples

```powershell
# Interactive mode (recommended)
.\Create-VHDX-Working.ps1

# Specify all parameters
.\Create-VHDX-Working.ps1 -ISOPath "C:\ISOs\Windows10.iso" -OutputDir "D:\VHDXs" -SizeGB 120 -EditionIndex 6
```

### Common Edition Numbers
- 1 = Home
- 6 = Pro (most common)
- 7 = Pro N

## Important Notes

- **DO NOT USE** `0-convert-ISO2VHDX-Main.ps1` on Server 2025 (it will hang)
- The conversion takes 5-15 minutes
- You need Administrator privileges
- No Hyper-V required!

## Other Scripts

All other scripts have been archived in the `archive` folder for reference but are not needed for normal use.