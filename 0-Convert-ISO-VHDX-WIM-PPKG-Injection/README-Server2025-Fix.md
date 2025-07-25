# Windows Server 2025 ISO to VHDX Conversion Fix

## Overview

This fix addresses a critical hanging issue when converting Windows ISOs to VHDX format on Windows Server 2025. The original Convert-WindowsImage module hangs indefinitely on Server 2025, preventing successful VHDX creation.

## Problem Description

When running the original conversion script on Windows Server 2025, the process hangs at:
```
Windows(R) Image to Virtual Hard Disk Converter for Windows(R)
Copyright (C) Microsoft Corporation.  All rights reserved.
Version 10.0.14278.1000.amd64fre.rs1_es_media.160201-1707
```

The script never progresses beyond this point, requiring manual termination.

## Root Cause

The Convert-WindowsImage module (from 2016) has compatibility issues with Windows Server 2025, likely due to:
- Changes in Hyper-V PowerShell cmdlet behavior
- DISM.exe implementation changes in Server 2025
- Enhanced security/process isolation in newer Windows versions

## Solution

We've created new scripts that bypass the problematic Convert-WindowsImage module entirely, using native Windows tools (DISKPART and DISM) directly.

## Which Script to Use

### 1. **Create-VHDX-Working.ps1** (RECOMMENDED)
- **Use when:** You need reliable VHDX creation on any Windows system
- **Requirements:** Administrator privileges only (no Hyper-V needed)
- **Compatibility:** Works on all Windows versions including Server 2025
- **Method:** Uses DISKPART + DISM directly

### 2. **0-convert-ISO2VHDX-Server2025-Fix.ps1**
- **Use when:** You have Hyper-V installed and want enhanced logging
- **Requirements:** Hyper-V role/feature installed
- **Compatibility:** Designed specifically for Server 2025
- **Method:** Hybrid approach with timeout handling

### 3. **Convert-ISO-Universal.ps1**
- **Use when:** You need detailed progress monitoring
- **Requirements:** Administrator privileges
- **Compatibility:** Universal Windows compatibility
- **Method:** DISKPART + DISM with extensive logging

### 4. **Convert-ISO-Direct.ps1**
- **Use when:** You have Hyper-V and prefer PowerShell cmdlets
- **Requirements:** Hyper-V PowerShell module
- **Compatibility:** Best for non-Server 2025 systems
- **Method:** Hyper-V cmdlets with fallback options

## Quick Start

```powershell
# Basic usage (uses Windows10.iso from C:\code\ISO\)
.\Create-VHDX-Working.ps1

# Custom ISO and output location
.\Create-VHDX-Working.ps1 -ISOPath "D:\ISOs\Windows11.iso" -OutputDir "E:\VHDXs" -SizeGB 120

# Specific Windows edition (default is 6 for Pro)
.\Create-VHDX-Working.ps1 -EditionIndex 4
```

## Key Discoveries

1. **Module Incompatibility**: The Convert-WindowsImage module (v10.0.14278.1000) is incompatible with Server 2025
2. **Direct Tool Access**: Using DISKPART and DISM directly provides better compatibility
3. **No Hyper-V Dependency**: VHDX creation doesn't require Hyper-V to be installed
4. **Universal Approach**: DISKPART + DISM work consistently across all Windows versions

## Script Comparison

| Script | Hyper-V Required | Server 2025 Compatible | Speed | Logging |
|--------|------------------|------------------------|-------|---------|
| Create-VHDX-Working.ps1 | No | Yes | Fast | Basic |
| 0-convert-ISO2VHDX-Server2025-Fix.ps1 | Yes | Yes | Medium | Extensive |
| Convert-ISO-Universal.ps1 | No | Yes | Medium | Detailed |
| Convert-ISO-Direct.ps1 | Yes | Partial | Fast | Basic |
| Original (Convert-WindowsImage) | Yes | No | N/A | Basic |

## Conversion Process

The working scripts perform these steps:
1. Create VHDX file using DISKPART
2. Initialize disk with GPT/MBR partition style
3. Create appropriate partitions (EFI, MSR, Windows)
4. Mount the ISO and locate install.wim/install.esd
5. Apply Windows image using DISM
6. Configure boot files with BCDBoot
7. Cleanup and detach

## Troubleshooting

### If conversion fails:
1. Ensure you're running as Administrator
2. Check available disk space (need 2x the VHDX size)
3. Verify ISO file is valid Windows installation media
4. Check DISM log in %TEMP% for detailed errors

### Common errors:
- "Could not find virtual disk" - DISKPART couldn't create/attach the VHDX
- "DISM failed with exit code" - Check if ISO is corrupted or edition index is invalid
- "Access denied" - Run PowerShell as Administrator

## Performance

- Typical conversion time: 5-15 minutes
- Depends on: ISO size, disk speed, system resources
- VHDX created as dynamic (thin provisioned) by default

## Future Recommendations

1. Always test on Server 2025 before deployment
2. Consider maintaining both approaches (module-based for older systems, direct tools for newer)
3. Monitor for updates to Convert-WindowsImage module
4. Use direct DISKPART/DISM approach for critical automation

## Contributing

If you encounter issues or have improvements:
1. Test thoroughly on Server 2025
2. Maintain backward compatibility
3. Document any new findings
4. Submit PR with detailed test results