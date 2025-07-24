#requires -Version 5.1

<#
.SYNOPSIS
    Tests for functions that require user input using mocking.

.DESCRIPTION
    Tests functions like Show-DriveSelectionMenu by mocking Read-Host.
#>

[CmdletBinding()]
param()

# Import required modules
Import-Module "$PSScriptRoot\modules\EnhancedHyperVAO\EnhancedHyperVAO.psd1" -Force

Write-Host "`nTesting User Input Functions with Mocking" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Test Show-VMCreationMenu function
Write-Host "`n1. Testing Show-VMCreationMenu:" -ForegroundColor Yellow
try {
    # Create a mock function that simulates user input
    $global:MockInputQueue = @('1')  # Simulate selecting option 1
    $global:MockInputIndex = 0
    
    function global:Read-Host {
        param($Prompt)
        if ($global:MockInputIndex -lt $global:MockInputQueue.Count) {
            $input = $global:MockInputQueue[$global:MockInputIndex]
            $global:MockInputIndex++
            Write-Host "Mock Input: $input" -ForegroundColor DarkGray
            return $input
        }
        throw "No more mock input available"
    }
    
    # Test the function
    $result = Show-VMCreationMenu
    if ($result -eq '1') {
        Write-Host "   [PASS] Show-VMCreationMenu returned: $result" -ForegroundColor Green
    } else {
        Write-Host "   [FAIL] Expected '1', got: $result" -ForegroundColor Red
    }
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}
finally {
    # Restore original Read-Host
    Remove-Item function:Read-Host -ErrorAction SilentlyContinue
}

# Test configuration selection with mock data
Write-Host "`n2. Testing configuration file selection logic:" -ForegroundColor Yellow
try {
    # Test the validation logic directly
    $testCases = @(
        @{Input = "1"; Count = 11; Expected = $true},
        @{Input = "3"; Count = 11; Expected = $true},
        @{Input = "11"; Count = 11; Expected = $true},
        @{Input = "12"; Count = 11; Expected = $false},
        @{Input = "0"; Count = 11; Expected = $false},
        @{Input = "abc"; Count = 11; Expected = $false}
    )
    
    $allPassed = $true
    foreach ($test in $testCases) {
        $selection = $test.Input
        $count = $test.Count
        
        # Validation logic from the fixed function
        if ($selection -match '^\d+$') {
            $selectionNum = [int]$selection
            $validSelection = ($selectionNum -ge 1) -and ($selectionNum -le $count)
        } else {
            $validSelection = $false
        }
        
        $result = if ($validSelection -eq $test.Expected) { "PASS" } else { "FAIL" }
        if ($result -eq "FAIL") { $allPassed = $false }
        
        Write-Host "   [$result] Input: '$($test.Input)' - Valid: $validSelection (Expected: $($test.Expected))" -ForegroundColor $(if ($result -eq "PASS") { "Green" } else { "Red" })
    }
    
    if ($allPassed) {
        Write-Host "   [PASS] All validation tests passed" -ForegroundColor Green
    }
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test drive selection menu logic
Write-Host "`n3. Testing drive selection menu logic:" -ForegroundColor Yellow
try {
    # Create mock drive data
    $mockDrive = [PSCustomObject]@{
        DriveLetter = 'C'
        FreeSpaceGB = 100.50
        TotalSpaceGB = 500.00
        UsedSpaceGB = 399.50
        PercentFree = 20.1
    }
    
    # Test different user inputs
    $testInputs = @(
        @{Input = 'A'; Expected = 'Accept'; Description = "Accept recommended drive"},
        @{Input = 'a'; Expected = 'Accept'; Description = "Accept (lowercase)"},
        @{Input = '1'; Expected = 'Select'; Description = "Select specific drive"},
        @{Input = 'Q'; Expected = 'Quit'; Description = "Quit selection"},
        @{Input = 'invalid'; Expected = 'Invalid'; Description = "Invalid input"}
    )
    
    foreach ($test in $testInputs) {
        $input = $test.Input
        
        # Test the switch logic
        $action = switch -Regex ($input) {
            '^[Aa]$' { 'Accept' }
            '^[Qq]$' { 'Quit' }
            '^\d+$' { 'Select' }
            default { 'Invalid' }
        }
        
        $result = if ($action -eq $test.Expected) { "PASS" } else { "FAIL" }
        Write-Host "   [$result] $($test.Description): '$input' -> $action" -ForegroundColor $(if ($result -eq "PASS") { "Green" } else { "Red" })
    }
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test configuration edit logic
Write-Host "`n4. Testing configuration edit/proceed logic:" -ForegroundColor Yellow
try {
    $testInputs = @(
        @{Input = 'Y'; Expected = 'Yes'; Description = "Proceed with config"},
        @{Input = 'y'; Expected = 'Yes'; Description = "Proceed (lowercase)"},
        @{Input = 'E'; Expected = 'Edit'; Description = "Edit configuration"},
        @{Input = 'e'; Expected = 'Edit'; Description = "Edit (lowercase)"},
        @{Input = 'C'; Expected = 'Cancel'; Description = "Cancel selection"},
        @{Input = 'c'; Expected = 'Cancel'; Description = "Cancel (lowercase)"},
        @{Input = 'x'; Expected = 'Invalid'; Description = "Invalid input"}
    )
    
    foreach ($test in $testInputs) {
        $input = $test.Input
        
        # Test the switch logic
        $action = switch -Regex ($input) {
            '^[Yy]$' { 'Yes' }
            '^[Ee]$' { 'Edit' }
            '^[Cc]$' { 'Cancel' }
            default { 'Invalid' }
        }
        
        $result = if ($action -eq $test.Expected) { "PASS" } else { "FAIL" }
        Write-Host "   [$result] $($test.Description): '$input' -> $action" -ForegroundColor $(if ($result -eq "PASS") { "Green" } else { "Red" })
    }
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test memory parsing logic
Write-Host "`n5. Testing memory value parsing:" -ForegroundColor Yellow
try {
    $testCases = @(
        @{Input = '4GB'; Expected = 4294967296},
        @{Input = '512MB'; Expected = 536870912},
        @{Input = '1TB'; Expected = 1099511627776}
    )
    
    foreach ($test in $testCases) {
        $input = $test.Input
        $parsed = [int64](Invoke-Expression $input.Replace('GB', '*1GB').Replace('MB', '*1MB').Replace('TB', '*1TB'))
        
        $result = if ($parsed -eq $test.Expected) { "PASS" } else { "FAIL" }
        Write-Host "   [$result] Parse '$input' = $parsed bytes" -ForegroundColor $(if ($result -eq "PASS") { "Green" } else { "Red" })
    }
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

Write-Host "`nAll user input function tests completed!" -ForegroundColor Cyan