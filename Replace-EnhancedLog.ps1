#Requires -Version 5.1
<#
.SYNOPSIS
    Replaces Write-EnhancedLog calls with appropriate Write-* cmdlets in PowerShell modules.

.DESCRIPTION
    This script processes all .ps1 and .psm1 files in the specified module directory and:
    - Replaces Write-EnhancedLog calls with appropriate Write-Host, Write-Verbose, Write-Error, Write-Warning, or Write-Debug
    - Removes Log-Params function calls
    - Preserves the original message content

.PARAMETER ModulePath
    The path to the module directory to process. Defaults to the EnhancedHyperVAO module directory.

.PARAMETER BackupFiles
    If specified, creates .bak backup files before making changes.

.EXAMPLE
    .\Replace-EnhancedLog.ps1
    Processes all PowerShell files in the default module directory.

.EXAMPLE
    .\Replace-EnhancedLog.ps1 -BackupFiles
    Processes all files and creates backups.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ModulePath = "D:\code\HyperV\2-Create-HyperV_VM\Latest\modules\EnhancedHyperVAO",
    
    [Parameter()]
    [switch]$BackupFiles
)

# Function to process a single file
function Process-PowerShellFile {
    param(
        [string]$FilePath,
        [bool]$CreateBackup
    )
    
    Write-Host "Processing: $FilePath" -ForegroundColor Cyan
    
    try {
        # Read the file content
        $content = Get-Content -Path $FilePath -Raw
        $originalContent = $content
        $changesMade = $false
        
        # Pattern to match Write-EnhancedLog calls
        $enhancedLogPattern = 'Write-EnhancedLog\s+-Message\s+"([^"]+)"\s+-Level\s+"(ERROR|WARNING|INFO|DEBUG|NOTICE)"(?:\s+-ForegroundColor\s+(?:\[ConsoleColor\]::)?(\w+))?'
        
        # Replace Write-EnhancedLog calls
        $content = [regex]::Replace($content, $enhancedLogPattern, {
            param($match)
            $message = $match.Groups[1].Value
            $level = $match.Groups[2].Value
            $color = $match.Groups[3].Value
            
            $changesMade = $true
            
            switch ($level) {
                "ERROR" {
                    return "Write-Error `"$message`""
                }
                "WARNING" {
                    return "Write-Warning `"$message`""
                }
                "INFO" {
                    if ($color) {
                        # If color was specified, use it with Write-Host
                        return "Write-Host `"$message`" -ForegroundColor $color"
                    } else {
                        return "Write-Host `"$message`""
                    }
                }
                "DEBUG" {
                    return "Write-Debug `"$message`""
                }
                "NOTICE" {
                    # Treat NOTICE as INFO
                    if ($color) {
                        return "Write-Host `"$message`" -ForegroundColor $color"
                    } else {
                        return "Write-Host `"$message`""
                    }
                }
                default {
                    # Default to Write-Host for any unknown levels
                    return "Write-Host `"$message`""
                }
            }
        })
        
        # Pattern to match Log-Params calls (entire line)
        $logParamsPattern = '^\s*Log-Params\s+-Params\s+.*$'
        
        # Remove Log-Params calls (remove entire lines)
        $lines = $content -split "`r?`n"
        $filteredLines = $lines | Where-Object { $_ -notmatch $logParamsPattern }
        
        if ($lines.Count -ne $filteredLines.Count) {
            $changesMade = $true
            $content = $filteredLines -join "`n"
        }
        
        # Only write back if changes were made
        if ($changesMade) {
            if ($CreateBackup) {
                $backupPath = "$FilePath.bak"
                Write-Host "  Creating backup: $backupPath" -ForegroundColor Gray
                Set-Content -Path $backupPath -Value $originalContent -NoNewline
            }
            
            Set-Content -Path $FilePath -Value $content -NoNewline
            Write-Host "  Changes applied successfully" -ForegroundColor Green
        } else {
            Write-Host "  No changes needed" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Error "Failed to process $FilePath : $_"
    }
}

# Main script logic
Write-Host "`nStarting Write-EnhancedLog replacement process..." -ForegroundColor Magenta
Write-Host "Module Path: $ModulePath" -ForegroundColor Cyan
Write-Host "Backup Files: $($BackupFiles.IsPresent)" -ForegroundColor Cyan
Write-Host ("-" * 60) -ForegroundColor Gray

# Verify the module path exists
if (-not (Test-Path -Path $ModulePath)) {
    Write-Error "Module path does not exist: $ModulePath"
    exit 1
}

# Get all PowerShell files in the module directory and subdirectories
$psFiles = Get-ChildItem -Path $ModulePath -Include "*.ps1", "*.psm1" -Recurse -File

if ($psFiles.Count -eq 0) {
    Write-Warning "No PowerShell files found in $ModulePath"
    exit 0
}

Write-Host "`nFound $($psFiles.Count) PowerShell file(s) to process" -ForegroundColor Cyan

# Process each file
foreach ($file in $psFiles) {
    Process-PowerShellFile -FilePath $file.FullName -CreateBackup $BackupFiles.IsPresent
}

Write-Host "`n$("-" * 60)" -ForegroundColor Gray
Write-Host "Processing complete!" -ForegroundColor Green

# Summary of replacements
Write-Host "`nReplacement Summary:" -ForegroundColor Magenta
Write-Host "  - Write-EnhancedLog -Level 'ERROR'   -> Write-Error" -ForegroundColor Red
Write-Host "  - Write-EnhancedLog -Level 'WARNING' -> Write-Warning" -ForegroundColor Yellow
Write-Host "  - Write-EnhancedLog -Level 'INFO'    -> Write-Host" -ForegroundColor Cyan
Write-Host "  - Write-EnhancedLog -Level 'DEBUG'   -> Write-Debug" -ForegroundColor Gray
Write-Host "  - Log-Params calls                   -> Removed" -ForegroundColor DarkGray

if ($BackupFiles.IsPresent) {
    Write-Host "`nBackup files created with .bak extension" -ForegroundColor Green
}