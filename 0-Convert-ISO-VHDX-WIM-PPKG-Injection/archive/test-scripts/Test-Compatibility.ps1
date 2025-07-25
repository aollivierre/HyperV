#requires -RunAsAdministrator

<#
.SYNOPSIS
    Tests if the system has the required tools for VHDX creation
#>

Write-Host "System Compatibility Check for VHDX Creation" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# Get OS Information
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "`nOperating System:" -ForegroundColor Yellow
Write-Host "  Name: $($os.Caption)"
Write-Host "  Version: $($os.Version)"
Write-Host "  Build: $($os.BuildNumber)"

# Check DISKPART
Write-Host "`nChecking DISKPART..." -ForegroundColor Yellow
$diskpartPath = "$env:SystemRoot\System32\diskpart.exe"
if (Test-Path $diskpartPath) {
    Write-Host "  ✓ DISKPART found" -ForegroundColor Green
    
    # Test VHDX support
    $testScript = @"
create vdisk file="$env:TEMP\test.vhdx" maximum=1 type=expandable
select vdisk file="$env:TEMP\test.vhdx"
detach vdisk
exit
"@
    $testScript | Out-File "$env:TEMP\diskpart_test.txt" -Encoding ASCII
    $result = diskpart /s "$env:TEMP\diskpart_test.txt" 2>&1
    Remove-Item "$env:TEMP\diskpart_test.txt" -Force
    Remove-Item "$env:TEMP\test.vhdx" -Force -ErrorAction SilentlyContinue
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ VHDX creation supported" -ForegroundColor Green
    } else {
        Write-Host "  ✗ VHDX creation failed - may need Windows 8/Server 2012 or newer" -ForegroundColor Red
    }
} else {
    Write-Host "  ✗ DISKPART not found!" -ForegroundColor Red
}

# Check DISM
Write-Host "`nChecking DISM..." -ForegroundColor Yellow
$dismPath = "$env:SystemRoot\System32\dism.exe"
if (Test-Path $dismPath) {
    Write-Host "  ✓ DISM found" -ForegroundColor Green
    $dismVersion = & $dismPath /? 2>&1 | Select-String "Version" | Select-Object -First 1
    Write-Host "  Version: $dismVersion"
} else {
    Write-Host "  ✗ DISM not found!" -ForegroundColor Red
}

# Check BCDBoot
Write-Host "`nChecking BCDBoot..." -ForegroundColor Yellow
$bcdbootPath = "$env:SystemRoot\System32\bcdboot.exe"
if (Test-Path $bcdbootPath) {
    Write-Host "  ✓ BCDBoot found" -ForegroundColor Green
} else {
    Write-Host "  ✗ BCDBoot not found!" -ForegroundColor Red
}

# Check PowerShell version
Write-Host "`nChecking PowerShell..." -ForegroundColor Yellow
Write-Host "  Version: $($PSVersionTable.PSVersion)"
if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-Host "  ✓ PowerShell 5+ detected" -ForegroundColor Green
} else {
    Write-Host "  ⚠ PowerShell 5+ recommended" -ForegroundColor Yellow
}

# Summary
Write-Host "`nCompatibility Summary:" -ForegroundColor Cyan
if ($os.BuildNumber -ge 9200) {  # Windows 8/Server 2012
    Write-Host "✓ This system should be compatible with Create-VHDX-Working.ps1" -ForegroundColor Green
} else {
    Write-Host "⚠ This system may have limited VHDX support (Windows 8/Server 2012+ required)" -ForegroundColor Yellow
}

# Recommendation
Write-Host "`nRecommendation:" -ForegroundColor Cyan
if ($os.BuildNumber -ge 26100) {  # Server 2025
    Write-Host "Use: Create-VHDX-Working.ps1 (Original script will hang)" -ForegroundColor Yellow
} else {
    Write-Host "Both original and new scripts should work on this system" -ForegroundColor Green
}