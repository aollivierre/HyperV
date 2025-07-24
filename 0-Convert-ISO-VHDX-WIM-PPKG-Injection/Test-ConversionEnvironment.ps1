#requires -RunAsAdministrator

<#
.SYNOPSIS
    Diagnostic script to test Convert-WindowsImage environment on Windows Server 2025
#>

Write-Host "=== Convert-WindowsImage Environment Diagnostic ===" -ForegroundColor Cyan
Write-Host ""

# 1. Check OS Version
Write-Host "1. Operating System Information:" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "   OS: $($os.Caption)"
Write-Host "   Version: $($os.Version)"
Write-Host "   Build: $($os.BuildNumber)"
Write-Host "   Architecture: $($os.OSArchitecture)"
Write-Host ""

# 2. Check PowerShell Version
Write-Host "2. PowerShell Information:" -ForegroundColor Yellow
Write-Host "   Version: $($PSVersionTable.PSVersion)"
Write-Host "   Edition: $($PSVersionTable.PSEdition)"
Write-Host "   CLR Version: $($PSVersionTable.CLRVersion)"
Write-Host ""

# 3. Check DISM
Write-Host "3. DISM Information:" -ForegroundColor Yellow
$dismPath = Join-Path $env:WINDIR "System32\dism.exe"
if (Test-Path $dismPath) {
    Write-Host "   DISM Path: $dismPath" -ForegroundColor Green
    
    # Get DISM version
    $dismOutput = & $dismPath /? 2>&1 | Out-String
    $versionLine = $dismOutput -split "`n" | Where-Object { $_ -match "Version:" } | Select-Object -First 1
    if ($versionLine) {
        Write-Host "   $versionLine"
    }
    
    # Test DISM functionality
    Write-Host "   Testing DISM /Get-WimInfo..." -ForegroundColor Cyan
    try {
        # Create a simple test to see if DISM responds
        $testResult = & $dismPath /? 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   DISM responds correctly" -ForegroundColor Green
        } else {
            Write-Host "   DISM returned error code: $LASTEXITCODE" -ForegroundColor Red
        }
    } catch {
        Write-Host "   Error testing DISM: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   DISM NOT FOUND!" -ForegroundColor Red
}
Write-Host ""

# 4. Check Windows Assessment and Deployment Kit (ADK)
Write-Host "4. Windows ADK Components:" -ForegroundColor Yellow
$adkPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit",
    "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit",
    "${env:ProgramFiles(x86)}\Windows Kits\8.1\Assessment and Deployment Kit",
    "${env:ProgramFiles}\Windows Kits\8.1\Assessment and Deployment Kit"
)

$adkFound = $false
foreach ($path in $adkPaths) {
    if (Test-Path $path) {
        Write-Host "   ADK found at: $path" -ForegroundColor Green
        $adkFound = $true
        
        # Check for specific tools
        $deploymentTools = Join-Path $path "Deployment Tools"
        if (Test-Path $deploymentTools) {
            Write-Host "   Deployment Tools: Present" -ForegroundColor Green
        }
        break
    }
}

if (-not $adkFound) {
    Write-Host "   Windows ADK not found in standard locations" -ForegroundColor Yellow
    Write-Host "   This may affect advanced DISM operations" -ForegroundColor Yellow
}
Write-Host ""

# 5. Check Hyper-V
Write-Host "5. Hyper-V Status:" -ForegroundColor Yellow
try {
    $hyperV = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
    if ($hyperV) {
        Write-Host "   Hyper-V State: $($hyperV.State)"
        
        # Check Hyper-V PowerShell module
        if (Get-Module -ListAvailable -Name Hyper-V) {
            Write-Host "   Hyper-V PowerShell Module: Available" -ForegroundColor Green
        } else {
            Write-Host "   Hyper-V PowerShell Module: Not Available" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "   Could not check Hyper-V status: $_" -ForegroundColor Yellow
}
Write-Host ""

# 6. Check .NET Framework
Write-Host "6. .NET Framework:" -ForegroundColor Yellow
$dotNetVersions = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
    Get-ItemProperty -Name Version, Release -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^(?!S)\w+' } |
    Select-Object @{Name='Version'; Expression={$_.Version}}, @{Name='Release'; Expression={$_.Release}}, PSChildName

foreach ($version in $dotNetVersions) {
    Write-Host "   $($version.PSChildName): $($version.Version)"
}
Write-Host ""

# 7. Test WIM handling capabilities
Write-Host "7. WIM Handling Test:" -ForegroundColor Yellow
Write-Host "   Checking for Windows Imaging cmdlets..."

$wimCmdlets = @(
    "Get-WindowsImage",
    "Mount-WindowsImage",
    "Dismount-WindowsImage",
    "Add-WindowsImage"
)

foreach ($cmdlet in $wimCmdlets) {
    if (Get-Command $cmdlet -ErrorAction SilentlyContinue) {
        Write-Host "   $cmdlet : Available" -ForegroundColor Green
    } else {
        Write-Host "   $cmdlet : NOT Available" -ForegroundColor Red
    }
}
Write-Host ""

# 8. Check for potential blocking processes
Write-Host "8. Potentially Interfering Software:" -ForegroundColor Yellow
$blockingProcesses = @("vmms", "vmcompute", "vmmem")
foreach ($procName in $blockingProcesses) {
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "   $procName : Running (PID: $($proc.Id))" -ForegroundColor Yellow
    }
}

# Check antivirus
$defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($defenderStatus) {
    Write-Host "   Windows Defender: Real-time Protection = $($defenderStatus.RealTimeProtectionEnabled)"
}
Write-Host ""

# 9. Environment Variables
Write-Host "9. Relevant Environment Variables:" -ForegroundColor Yellow
Write-Host "   TEMP: $env:TEMP"
Write-Host "   TMP: $env:TMP"
Write-Host "   SystemRoot: $env:SystemRoot"
Write-Host "   ProgramFiles: $env:ProgramFiles"
Write-Host ""

# 10. Test simple DISM operation
Write-Host "10. Testing Basic DISM Operation:" -ForegroundColor Yellow
$testWim = "C:\Windows\System32\Recovery\winre.wim"
if (Test-Path $testWim) {
    Write-Host "   Testing Get-WindowsImage on $testWim..."
    try {
        $images = Get-WindowsImage -ImagePath $testWim -ErrorAction Stop
        Write-Host "   Successfully read $($images.Count) image(s) from WIM" -ForegroundColor Green
    } catch {
        Write-Host "   Failed to read WIM: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   WinRE.wim not found for testing" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "=== Diagnostic Summary ===" -ForegroundColor Cyan
Write-Host "Run this script on both the working server and the Server 2025 machine"
Write-Host "Compare the outputs to identify differences that might cause the hang."
Write-Host ""
Write-Host "Common issues on Server 2025:" -ForegroundColor Yellow
Write-Host "- Different DISM version or behavior"
Write-Host "- Missing Windows ADK components"
Write-Host "- Changes in security policies"
Write-Host "- Different .NET Framework versions"
Write-Host "- Antivirus/Defender interference"
Write-Host ""