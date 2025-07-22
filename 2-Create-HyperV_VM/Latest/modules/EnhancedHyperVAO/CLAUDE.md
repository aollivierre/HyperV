# EnhancedHyperVAO Module Refactoring Plan

## Overview
This document outlines the plan to refactor the EnhancedHyperVAO module from individual PS1 files into logically grouped PSM1 module files. This refactoring will improve maintainability, reduce file clutter, and create a more organized module structure.

## Current Structure
The module currently has 22 individual PS1 files in the Public folder, each containing a single function. This granular approach makes it difficult to manage related functionality and increases the number of files to maintain.

## Proposed PSM1 Module Structure

### 1. **VMCreation.psm1**
Groups all VM creation and folder management functions:
- `New-CustomVMWithDifferencingDisk`
- `New-DifferencingVHDX`
- `Show-VMCreationMenu`
- `CreateVMFolder`

### 2. **VMConfiguration.psm1**
Contains all VM configuration-related functions:
- `ConfigureVM`
- `ConfigureVMBoot`
- `Add-DVDDriveToVM`
- `EnableVMTPM`
- `EnsureUntrustedGuardianExists`

### 3. **VMOperations.psm1**
Handles VM runtime operations:
- `Start-VMEnhanced`
- `Connect-VMConsole`
- `Shutdown-DependentVMs`

### 4. **VMInformation.psm1**
Provides VM information and discovery functions:
- `Get-VMConfiguration`
- `Get-DependentVMs`
- `Get-NextVMNamePrefix`

### 5. **VMValidation.psm1**
Contains all validation functions:
- `Validate-VMExists`
- `Validate-VMStarted`
- `Validate-ISOAdded`
- `Validate-VHDMount`

### 6. **StorageManagement.psm1**
Disk and storage-related operations:
- `Dismount-VHDX`

### 7. **SystemUtilities.psm1**
System initialization and utility functions:
- `Initialize-HyperVServices`
- `Parse-Size`

## Benefits of Refactoring

1. **Reduced File Count**: From 22 PS1 files to 7 PSM1 files
2. **Logical Grouping**: Related functions are grouped together
3. **Easier Navigation**: Developers can find related functions in the same file
4. **Better Performance**: Fewer files to load during module import
5. **Improved Maintainability**: Changes to related functions can be made in one file

## Migration Strategy

### Phase 1: Create PSM1 Files
1. Create new PSM1 files in a new `Modules` subfolder
2. Copy functions from PS1 files to appropriate PSM1 files
3. Ensure all functions maintain their original structure and functionality

### Phase 2: Update Module Loader
1. Modify `EnhancedHyperVAO.psm1` to load from both Public and Modules folders
2. Test that all functions are properly exported
3. Verify no breaking changes in function availability

### Phase 3: Transition Period
1. Keep both PS1 and PSM1 files during testing
2. Update any internal function calls if needed
3. Test all functionality thoroughly

### Phase 4: Cleanup
1. Remove old PS1 files from Public folder
2. Update documentation
3. Create migration guide for users

## Module Loading Strategy

### Current Loading Method (EnhancedHyperVAO.psm1)
```powershell
# Current: Loads individual PS1 files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
```

### New Loading Method
```powershell
# Load PSM1 modules
$Modules = @(Get-ChildItem -Path $PSScriptRoot\Modules\*.psm1 -ErrorAction SilentlyContinue)
foreach ($Module in $Modules) {
    try {
        Import-Module $Module.FullName -Force -Scope Global
        # Export all functions from the sub-module
        $ModuleFunctions = Get-Command -Module $Module.BaseName -CommandType Function
        Export-ModuleMember -Function $ModuleFunctions.Name
    } catch {
        Write-Error "Failed to import module $($Module.Name): $_"
    }
}

# Continue loading any remaining PS1 files during transition
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
```

## Function Export Strategy

Each PSM1 file should export its functions explicitly:

```powershell
# At the end of each PSM1 file
Export-ModuleMember -Function @(
    'Function1',
    'Function2',
    'Function3'
)
```

## Testing Plan

1. **Unit Tests**: Create Pester tests for each PSM1 module
2. **Integration Tests**: Test function interactions across modules
3. **Performance Tests**: Compare module load times before and after
4. **Compatibility Tests**: Ensure no breaking changes for existing scripts

## Timeline

- **Week 1**: Create PSM1 files and migrate functions
- **Week 2**: Update module loader and test functionality
- **Week 3**: Transition period with parallel structures
- **Week 4**: Clean up and finalize documentation

## Considerations

1. **Backward Compatibility**: Ensure all exported functions remain available
2. **Documentation**: Update help files and README
3. **Dependencies**: Verify cross-function dependencies work correctly
4. **Error Handling**: Maintain consistent error handling across modules
5. **Logging**: Ensure Write-EnhancedLog continues to work properly

## Next Steps

1. Review and approve this refactoring plan
2. Create a feature branch for the refactoring work
3. Begin Phase 1 implementation
4. Set up automated testing

## Commands to Run

When implementing changes, ensure code quality by running:
```bash
# PowerShell script analyzer (if available)
Invoke-ScriptAnalyzer -Path . -Recurse

# Pester tests (if available)
Invoke-Pester

# Module import test
Import-Module .\EnhancedHyperVAO.psd1 -Force -Verbose
```