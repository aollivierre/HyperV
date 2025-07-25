# IMPORTANT: Windows Server 2025 Users

## Quick Fix

If you're on Windows Server 2025 and experiencing hanging issues, use:

```powershell
.\Create-VHDX-Working.ps1
```

This script bypasses the problematic Convert-WindowsImage module and works reliably on Server 2025.

## Details

See [README-Server2025-Fix.md](README-Server2025-Fix.md) for full documentation.