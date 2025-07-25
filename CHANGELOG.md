# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-01-25

### Added
- Windows Server 2025 compatibility fix for ISO to VHDX conversion
- New script: `Create-VHDX-Working.ps1` - Universal VHDX creation without Hyper-V dependency
- New script: `0-convert-ISO2VHDX-Server2025-Fix.ps1` - Enhanced version with timeout handling
- New script: `Convert-ISO-Universal.ps1` - Detailed progress monitoring version
- New script: `Convert-ISO-Direct.ps1` - Hyper-V cmdlet approach
- Comprehensive documentation for Server 2025 compatibility
- VHDX validation scripts for testing

### Changed
- Conversion approach now uses DISKPART and DISM directly instead of Convert-WindowsImage module
- Removed dependency on Hyper-V role for basic VHDX creation
- Improved error handling and progress reporting

### Fixed
- Critical hanging issue on Windows Server 2025 when using Convert-WindowsImage module
- DISM apply-image operation hanging indefinitely on Server 2025
- Process isolation issues with newer Windows versions

### Discovered
- Convert-WindowsImage module (v10.0.14278.1000 from 2016) is incompatible with Server 2025
- Direct DISKPART/DISM approach provides better cross-version compatibility
- Hyper-V PowerShell module not required for VHDX creation

## [1.0.0] - Previous Version

### Initial Release
- Original ISO to VHDX conversion using Convert-WindowsImage module
- Support for multiple Windows editions
- Dynamic and fixed disk options
- UEFI and BIOS boot support