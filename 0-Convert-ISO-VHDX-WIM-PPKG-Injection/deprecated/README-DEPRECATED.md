# DEPRECATED Scripts

## Warning

The scripts in this folder are known to have issues on Windows Server 2025 and newer systems.

### Known Issues

- `0-convert-ISO2VHDX-Main.ps1` - Hangs indefinitely on Server 2025
- `Convert-ISO2VHDX.psm1` module - Incompatible with Server 2025

### Symptoms

The conversion process hangs at:
```
Windows(R) Image to Virtual Hard Disk Converter for Windows(R)
Copyright (C) Microsoft Corporation.  All rights reserved.
Version 10.0.14278.1000.amd64fre.rs1_es_media.160201-1707
```

### Use Instead

For Windows Server 2025 and newer, use:
- `../Create-VHDX-Working.ps1` - Recommended solution
- See `../README-Server2025-Fix.md` for details

### When These Scripts Still Work

These scripts may still function on:
- Windows Server 2022 and earlier
- Windows 10/11 with Hyper-V
- Systems where Convert-WindowsImage module is compatible

### Why Kept

These scripts are preserved for:
- Historical reference
- Systems where they still function
- Understanding the original approach
- Comparison with the new solution