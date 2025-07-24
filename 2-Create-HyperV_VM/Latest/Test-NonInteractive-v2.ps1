#requires -Version 5.1

<#
.SYNOPSIS
    Non-interactive test that simulates the entire flow without user input.

.DESCRIPTION
    Tests the complete VM creation process with smart defaults and no user interaction.
#>

[CmdletBinding()]
param()

# Create a test configuration file
$testConfigPath = "$PSScriptRoot\test-noninteractive.psd1"
$testConfig = @'
@{
    VMNamePrefixFormat = '{0:D3} - Test - NonInteractive'
    InstallMediaPath = 'C:\test-noninteractive.iso'
    ProcessorCount = 'All Cores'
    SwitchName = 'Default Switch'
    Generation = 2
    VMType = 'Standard'
    MemoryStartupBytes = '2GB'
    MemoryMinimumBytes = '1GB'
    MemoryMaximumBytes = '4GB'
}
'@

Write-Host "Creating test configuration file..." -ForegroundColor Cyan
$testConfig | Out-File -FilePath $testConfigPath -Force

# Create a dummy ISO file for testing
$dummyIsoPath = "C:\test-noninteractive.iso"
if (-not (Test-Path $dummyIsoPath)) {
    Write-Host "Creating dummy ISO file..." -ForegroundColor Cyan
    "Dummy ISO content" | Out-File -FilePath $dummyIsoPath -Force
}

Write-Host "`nStarting non-interactive test..." -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Test the main script with all smart defaults enabled
try {
    Write-Host "`nRunning main script with -UseSmartDefaults and -AutoSelectDrive..." -ForegroundColor Yellow
    
    # Run the script with all non-interactive flags
    & "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
        -UseSmartDefaults `
        -AutoSelectDrive `
        -ConfigurationPath $PSScriptRoot `
        -EnvironmentMode 'dev' `
        -LogPath "$PSScriptRoot\Logs" `
        -MinimumFreeSpaceGB 10
    
    Write-Host "`n[SUCCESS] Script completed without user interaction!" -ForegroundColor Green
}
catch {
    Write-Host "`n[FAIL] Script failed: $_" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}

# Cleanup
Write-Host "`nCleaning up test files..." -ForegroundColor Cyan
Remove-Item -Path $testConfigPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $dummyIsoPath -Force -ErrorAction SilentlyContinue

Write-Host "`nNon-interactive test complete!" -ForegroundColor Cyan