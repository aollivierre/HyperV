# Changelog

All notable changes to the EnhancedHyperVAO module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-13

### 🔄 **MAJOR REFACTORING - BREAKING CHANGES**

This version represents a complete architectural overhaul of the EnhancedHyperVAO module, transitioning from individual PS1 files to logically grouped PSM1 module files.

### ✨ **Added**
- **New Modular Structure**: Introduced 7 PSM1 module files for better organization
- **VMCreation.psm1**: Centralized VM creation and folder management functions
- **VMConfiguration.psm1**: Consolidated VM configuration-related functions
- **VMOperations.psm1**: Grouped VM runtime operations
- **VMInformation.psm1**: Organized VM information and discovery functions
- **VMValidation.psm1**: Centralized all validation functions
- **StorageManagement.psm1**: Dedicated storage operations module
- **SystemUtilities.psm1**: System initialization and utility functions
- **Enhanced Module Loader**: New PSM1-based loading mechanism in `EnhancedHyperVAO.psm1`
- **Improved Documentation**: Updated inline documentation and module structure comments

### 🔧 **Changed**
- **Module Loading Strategy**: Completely rewritten to load PSM1 modules instead of individual PS1 files
- **Function Organization**: Reorganized 22 functions into 7 logical groups
- **File Structure**: Streamlined from 22 PS1 files to 7 PSM1 files (68% reduction)
- **Performance**: Improved module load times with fewer files to process
- **Maintainability**: Related functions now grouped together for easier maintenance

### 🗑️ **Removed**
- **Public Directory**: Eliminated the Public folder containing individual PS1 files
- **22 Individual PS1 Files**: All functions migrated to appropriate PSM1 modules
- **Transition Code**: Removed temporary compatibility code for PS1/PSM1 coexistence

### 📦 **Migration Guide**
- **No Code Changes Required**: All function names and signatures remain identical
- **Import Statement**: Continue using `Import-Module EnhancedHyperVAO` - no changes needed
- **Function Availability**: All 22 functions remain available with same functionality

### 🏗️ **Module Structure Before vs After**

#### Before (v1.x):
```
EnhancedHyperVAO/
├── Public/
│   ├── Add-DVDDriveToVM.ps1
│   ├── ConfigureVM.ps1
│   ├── ConfigureVMBoot.ps1
│   └── ... (19 more PS1 files)
└── EnhancedHyperVAO.psm1
```

#### After (v2.0):
```
EnhancedHyperVAO/
├── Modules/
│   ├── VMCreation.psm1
│   ├── VMConfiguration.psm1
│   ├── VMOperations.psm1
│   ├── VMInformation.psm1
│   ├── VMValidation.psm1
│   ├── StorageManagement.psm1
│   └── SystemUtilities.psm1
└── EnhancedHyperVAO.psm1
```

### 📊 **Function Distribution**

| Module | Functions | Purpose |
|--------|-----------|---------|
| VMCreation | 4 | `New-CustomVMWithDifferencingDisk`, `New-DifferencingVHDX`, `Show-VMCreationMenu`, `CreateVMFolder` |
| VMConfiguration | 5 | `ConfigureVM`, `ConfigureVMBoot`, `Add-DVDDriveToVM`, `EnableVMTPM`, `EnsureUntrustedGuardianExists` |
| VMOperations | 3 | `Start-VMEnhanced`, `Connect-VMConsole`, `Shutdown-DependentVMs` |
| VMInformation | 3 | `Get-VMConfiguration`, `Get-DependentVMs`, `Get-NextVMNamePrefix` |
| VMValidation | 4 | `Validate-VMExists`, `Validate-VMStarted`, `Validate-ISOAdded`, `Validate-VHDMount` |
| StorageManagement | 1 | `Dismount-VHDX` |
| SystemUtilities | 2 | `Initialize-HyperVServices`, `Parse-Size` |

### 🎯 **Benefits**
- **Reduced Complexity**: 68% fewer files to manage
- **Logical Organization**: Related functions grouped together
- **Better Performance**: Faster module loading
- **Improved Navigation**: Easier to find and maintain related functions
- **Enhanced Maintainability**: Changes to related functions can be made in one file
- **Future-Proof**: Scalable architecture for future enhancements

### ⚠️ **Breaking Changes**
- **File Structure**: Direct access to individual PS1 files no longer possible
- **Development Workflow**: Contributors must now work with PSM1 files instead of individual PS1 files

### 🔍 **Technical Details**
- **Module Loader**: Enhanced to dynamically import PSM1 modules
- **Function Export**: Automatic detection and export of all functions from PSM1 modules
- **Error Handling**: Improved error handling during module loading
- **Logging**: Enhanced logging for module loading process

---

## [1.x.x] - Previous Versions

### Legacy Structure
- Individual PS1 files in Public directory
- Basic module loader
- 22 separate function files