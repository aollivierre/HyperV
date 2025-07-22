<#
.SYNOPSIS
    Script that initiates the EnhancedHyperVAO module.

.DESCRIPTION
    This script dynamically loads functions from PSM1 module files in the Modules directory.
    All functions from PSM1 modules are exported and available for external use.
    Functions in the 'Private' directory (if any) are intended for internal module use only.

.NOTES
    Author: Abdullah Ollivierre
    Contact:
    Website:
    
    Module Structure:
    - VMCreation.psm1: VM creation and folder management functions
    - VMConfiguration.psm1: VM configuration-related functions  
    - VMOperations.psm1: VM runtime operations
    - VMInformation.psm1: VM information and discovery functions
    - VMValidation.psm1: All validation functions
    - StorageManagement.psm1: Disk and storage-related operations
    - SystemUtilities.psm1: System initialization and utility functions
#>

[CmdletBinding()]
Param()

Process {
    # Initialize arrays to store all function names to export
    $allFunctionsToExport = @()
    
    # Load PSM1 modules from Modules directory
    $modulesDir = Join-Path -Path $PSScriptRoot -ChildPath "Modules"
    $ModuleFiles = @(Get-ChildItem -Path $modulesDir -Filter "*.psm1" -ErrorAction SilentlyContinue)
    
    Write-Host "Module files found: $($ModuleFiles.Count)"
    
    # Import PSM1 modules
    foreach ($ModuleFile in $ModuleFiles) {
        try {
            Write-Host "Importing module: $($ModuleFile.FullName)"
            Import-Module $ModuleFile.FullName -Force -DisableNameChecking
            
            # Get functions from the imported module
            $moduleName = $ModuleFile.BaseName
            $moduleFunctions = Get-Command -Module $moduleName -CommandType Function | Select-Object -ExpandProperty Name
            
            if ($moduleFunctions) {
                Write-Host "Functions from $moduleName`: $($moduleFunctions -join ', ')"
                $allFunctionsToExport += $moduleFunctions
            }
        }
        catch {
            Write-Error "Failed to import module from $($ModuleFile.FullName) with error: $($_.Exception.Message)"
        }
    }
    
    # Load any remaining PS1 files from Private directory only (for internal functions)
    $privateDir = Join-Path -Path $PSScriptRoot -ChildPath "Private"
    $PrivateFunctions = @(Get-ChildItem -Path $privateDir -Filter "*.ps1" -ErrorAction SilentlyContinue)

    if ($PrivateFunctions.Count -gt 0) {
        Write-Host "Private PS1 Functions found: $($PrivateFunctions.Count)"
        
        # Dot-source private functions (these are not exported)
        foreach ($FunctionFile in $PrivateFunctions) {
            try {
                Write-Host "Dot-sourcing private function: $($FunctionFile.FullName)"
                . $FunctionFile.FullName
            }
            catch {
                Write-Error "Failed to import private function from $($FunctionFile.FullName) with error: $($_.Exception.Message)"
            }
        }
    }
    
    # Export all functions from PSM1 modules
    if ($allFunctionsToExport) {
        # Remove duplicates
        $allFunctionsToExport = $allFunctionsToExport | Select-Object -Unique
        Write-Host "Exporting functions: $($allFunctionsToExport -join ', ')"
        Export-ModuleMember -Function $allFunctionsToExport -Alias *
    }
    else {
        Write-Warning "No functions found to export."
    }
}
