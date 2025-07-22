#requires -Version 5.1

<#
.SYNOPSIS
    Tests the refactored Hyper-V VM creation script.

.DESCRIPTION
    This script validates that the refactored script can be imported and basic functionality works.
#>

[CmdletBinding()]
param()

$TestResults = @()

function Test-ScriptComponent {
    param(
        [string]$TestName,
        [scriptblock]$TestScript
    )
    
    $result = @{
        TestName = $TestName
        Success = $false
        Error = $null
    }
    
    try {
        & $TestScript
        $result.Success = $true
        Write-Host "[PASS] $TestName" -ForegroundColor Green
    }
    catch {
        $result.Success = $false
        $result.Error = $_.Exception.Message
        Write-Host "[FAIL] $TestName - $_" -ForegroundColor Red
    }
    
    return $result
}

Write-Host "`nStarting validation of refactored Hyper-V script..." -ForegroundColor Cyan
Write-Host "=" * 60

# Test 1: Check if the script exists
$TestResults += Test-ScriptComponent -TestName "Script file exists" -TestScript {
    $scriptPath = "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v3-Refactored-CLEANED.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "Script file not found at: $scriptPath"
    }
}

# Test 2: Check if the Enhanced-HyperV module exists
$TestResults += Test-ScriptComponent -TestName "Enhanced-HyperV module exists" -TestScript {
    $modulePath = "$PSScriptRoot\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1"
    if (-not (Test-Path $modulePath)) {
        throw "Module not found at: $modulePath"
    }
}

# Test 3: Test module import
$TestResults += Test-ScriptComponent -TestName "Import Enhanced-HyperV module" -TestScript {
    $modulePath = "$PSScriptRoot\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1"
    Import-Module $modulePath -Force -ErrorAction Stop
}

# Test 4: Verify custom logging function in script
$TestResults += Test-ScriptComponent -TestName "Custom logging function exists" -TestScript {
    $scriptContent = Get-Content "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v3-Refactored-CLEANED.ps1" -Raw
    if ($scriptContent -notmatch 'function Write-Log') {
        throw "Write-Log function not found in script"
    }
}

# Test 5: Check for removed dependencies
$TestResults += Test-ScriptComponent -TestName "Unnecessary dependencies removed" -TestScript {
    $scriptContent = Get-Content "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v3-Refactored-CLEANED.ps1" -Raw
    
    $removedDependencies = @(
        'Invoke-ModuleStarter',
        'PSFramework',
        'WriteLogEntry',
        'Write-EnhancedLog',
        'Set-PSFLoggingProvider',
        'Get-PSFCSVLogFilePath'
    )
    
    foreach ($dep in $removedDependencies) {
        if ($scriptContent -match $dep) {
            throw "Found removed dependency: $dep"
        }
    }
}

# Test 6: Verify no Write-EnhancedLog in module
$TestResults += Test-ScriptComponent -TestName "Write-EnhancedLog removed from module" -TestScript {
    $moduleFiles = Get-ChildItem "$PSScriptRoot\modules\EnhancedHyperVAO" -Recurse -Include "*.ps1", "*.psm1" | 
        Where-Object { $_.Name -notlike "*.bak" }
    
    foreach ($file in $moduleFiles) {
        $content = Get-Content $file.FullName -Raw
        if ($content -match 'Write-EnhancedLog') {
            throw "Found Write-EnhancedLog in: $($file.Name)"
        }
    }
}

# Test 7: Syntax validation
$TestResults += Test-ScriptComponent -TestName "Script syntax validation" -TestScript {
    $scriptPath = "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v3-Refactored-CLEANED.ps1"
    $errors = @()
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
    if ($errors.Count -gt 0) {
        throw "Syntax errors found: $($errors -join ', ')"
    }
}

# Test 8: Module syntax validation
$TestResults += Test-ScriptComponent -TestName "Module syntax validation" -TestScript {
    $moduleFiles = Get-ChildItem "$PSScriptRoot\modules\EnhancedHyperVAO" -Recurse -Include "*.ps1", "*.psm1" | 
        Where-Object { $_.Name -notlike "*.bak" }
    
    foreach ($file in $moduleFiles) {
        $errors = @()
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$errors)
        if ($errors.Count -gt 0) {
            throw "Syntax errors in $($file.Name): $($errors -join ', ')"
        }
    }
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$passedTests = ($TestResults | Where-Object { $_.Success }).Count
$failedTests = ($TestResults | Where-Object { -not $_.Success }).Count

Write-Host "Total Tests: $($TestResults.Count)" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { 'Green' } else { 'Red' })

if ($failedTests -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $TestResults | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  - $($_.TestName): $($_.Error)" -ForegroundColor Red
    }
}

Write-Host "`nValidation complete!" -ForegroundColor Cyan

# Return exit code based on test results
exit $(if ($failedTests -eq 0) { 0 } else { 1 })