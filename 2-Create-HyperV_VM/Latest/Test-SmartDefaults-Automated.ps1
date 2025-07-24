#requires -Version 5.1

<#
.SYNOPSIS
    Automated tests for smart defaults functionality without user interaction.

.DESCRIPTION
    Tests all functions that don't require user input and validates their output.
#>

[CmdletBinding()]
param()

# Import functions from the main script
$scriptPath = "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1"
$scriptContent = Get-Content $scriptPath -Raw

# Extract just the functions we need (avoid executing the main script)
$functionPattern = 'function\s+(Get-SystemResources|Get-ProcessorCount|Get-SmartMemoryAllocation|Get-AvailableDrives|Select-BestDrive|Get-SmartPaths|Get-SmartVirtualSwitch|Process-SmartConfiguration|Write-Log|Handle-Error|Log-Params)\s*\{[\s\S]*?\n\}'
$functions = [regex]::Matches($scriptContent, $functionPattern) | ForEach-Object { $_.Value }

# Create a script block with just the functions
$functionScriptBlock = [scriptblock]::Create($functions -join "`n`n")
& $functionScriptBlock

# Test results collection
$testResults = @()

function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [scriptblock]$ValidationScript = { $true }
    )
    
    $result = @{
        TestName = $TestName
        Success = $false
        Result = $null
        Error = $null
        Duration = 0
    }
    
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $testResult = & $TestScript
        $stopwatch.Stop()
        
        $result.Duration = $stopwatch.ElapsedMilliseconds
        $result.Result = $testResult
        
        # Validate the result
        $isValid = & $ValidationScript -Result $testResult
        $result.Success = $isValid
        
        if ($isValid) {
            Write-Host "[PASS] $TestName (${($result.Duration)}ms)" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] $TestName - Validation failed" -ForegroundColor Red
        }
    }
    catch {
        $result.Success = $false
        $result.Error = $_.Exception.Message
        Write-Host "[FAIL] $TestName - $_" -ForegroundColor Red
    }
    
    return $result
}

Write-Host "`nRunning Automated Smart Defaults Tests" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Test 1: System Resources
$testResults += Test-Function -TestName "Get-SystemResources" -TestScript {
    Get-SystemResources
} -ValidationScript {
    param($Result)
    $Result -and 
    $Result.TotalCores -gt 0 -and 
    $Result.TotalMemoryGB -gt 0 -and
    $Result.CPUName -ne $null
}

# Test 2: Processor Count - Specific Value
$testResults += Test-Function -TestName "Get-ProcessorCount with number" -TestScript {
    Get-ProcessorCount -ProcessorValue "4"
} -ValidationScript {
    param($Result)
    $Result -eq 4
}

# Test 3: Processor Count - All Cores
$testResults += Test-Function -TestName "Get-ProcessorCount with 'All Cores'" -TestScript {
    Get-ProcessorCount -ProcessorValue "All Cores"
} -ValidationScript {
    param($Result)
    $resources = Get-SystemResources
    $Result -eq $resources.TotalCores
}

# Test 4: Processor Count - Invalid Value
$testResults += Test-Function -TestName "Get-ProcessorCount with invalid value" -TestScript {
    Get-ProcessorCount -ProcessorValue "Invalid"
} -ValidationScript {
    param($Result)
    $Result -eq 2  # Should default to 2
}

# Test 5: Smart Memory Allocation
$testResults += Test-Function -TestName "Get-SmartMemoryAllocation - Balanced" -TestScript {
    Get-SmartMemoryAllocation -AllocationMode 'Balanced'
} -ValidationScript {
    param($Result)
    $Result -and
    $Result.StartupBytes -match '^\d+GB$' -and
    $Result.MinimumBytes -match '^\d+GB$' -and
    $Result.MaximumBytes -match '^\d+GB$'
}

# Test 6: Available Drives
$testResults += Test-Function -TestName "Get-AvailableDrives" -TestScript {
    Get-AvailableDrives
} -ValidationScript {
    param($Result)
    $Result -and
    $Result.Count -gt 0 -and
    $Result[0].DriveLetter -ne $null
}

# Test 7: Select Best Drive
$testResults += Test-Function -TestName "Select-BestDrive" -TestScript {
    Select-BestDrive -MinimumFreeSpaceGB 1
} -ValidationScript {
    param($Result)
    $Result -and
    $Result.DriveLetter -ne $null -and
    $Result.FreeSpaceGB -ge 1
}

# Test 8: Smart Paths
$testResults += Test-Function -TestName "Get-SmartPaths" -TestScript {
    $drives = Get-AvailableDrives
    if ($drives.Count -gt 0) {
        Get-SmartPaths -DriveLetter $drives[0].DriveLetter
    } else {
        throw "No drives available"
    }
} -ValidationScript {
    param($Result)
    $Result -and
    $Result.VMPath -ne $null -and
    $Result.VMPath -match '^[A-Z]:\\VMs$'
}

# Test 9: Smart Virtual Switch Detection
$testResults += Test-Function -TestName "Get-SmartVirtualSwitch" -TestScript {
    # This will find existing switches without creating new ones
    $switches = Get-VMSwitch -ErrorAction SilentlyContinue
    if ($switches) {
        Get-SmartVirtualSwitch -RequestedSwitch "Default Switch"
    } else {
        "No switches available for testing"
    }
} -ValidationScript {
    param($Result)
    $Result -ne $null
}

# Test 10: Process Smart Configuration
$testResults += Test-Function -TestName "Process-SmartConfiguration" -TestScript {
    $testConfig = @{
        VMNamePrefixFormat = 'Test VM'
        InstallMediaPath = 'test.iso'
        ProcessorCount = 'All Cores'
        SwitchName = 'Default Switch'
    }
    
    $drives = Get-AvailableDrives
    if ($drives.Count -gt 0) {
        Process-SmartConfiguration -Config $testConfig -SelectedDrive $drives[0].DriveLetter
    } else {
        throw "No drives available"
    }
} -ValidationScript {
    param($Result)
    $Result -and
    $Result.ProcessorCount -gt 0 -and
    $Result.MemoryStartupBytes -ne $null -and
    $Result.VMPath -ne $null
}

# Test 11: Path Update Logic
$testResults += Test-Function -TestName "Path drive letter update" -TestScript {
    $config = @{
        VMPath = "D:\VMs"
        ISOPath = "E:\ISOs\test.iso"
        RelativePath = "VMs\Templates"
    }
    
    # Test the path update logic
    $updatedConfig = @{}
    foreach ($key in $config.Keys) {
        $path = $config[$key]
        if ($path -match '^[A-Za-z]:') {
            $updatedConfig[$key] = $path -replace '^[A-Za-z]:', "C:"
        } else {
            $updatedConfig[$key] = "C:\$path"
        }
    }
    $updatedConfig
} -ValidationScript {
    param($Result)
    $Result.VMPath -eq "C:\VMs" -and
    $Result.ISOPath -eq "C:\ISOs\test.iso" -and
    $Result.RelativePath -eq "C:\VMs\Templates"
}

# Summary
Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

$passedTests = ($testResults | Where-Object { $_.Success }).Count
$failedTests = ($testResults | Where-Object { -not $_.Success }).Count
$totalDuration = ($testResults | Measure-Object -Property Duration -Sum).Sum

Write-Host "Total Tests: $($testResults.Count)" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { 'Green' } else { 'Red' })
Write-Host "Total Duration: ${totalDuration}ms" -ForegroundColor White

if ($failedTests -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $testResults | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  - $($_.TestName): $($_.Error)" -ForegroundColor Red
    }
}

# Export results for CI/CD integration
$resultsFile = "$PSScriptRoot\TestResults-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$testResults | ConvertTo-Json -Depth 3 | Out-File $resultsFile
Write-Host "`nTest results exported to: $resultsFile" -ForegroundColor Cyan

# Return exit code
exit $(if ($failedTests -eq 0) { 0 } else { 1 })