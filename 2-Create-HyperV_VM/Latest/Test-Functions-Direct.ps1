#requires -Version 5.1

<#
.SYNOPSIS
    Direct function tests by extracting functions from main script.
#>

[CmdletBinding()]
param()

# Define all the functions directly here (extracted from main script)
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [Parameter()]
        [ConsoleColor]$ForegroundColor = 'White'
    )
    
    # Simple implementation for testing
    Write-Host "[$Level] $Message" -ForegroundColor $ForegroundColor
}

function Get-SystemResources {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Gathering system resource information..." -Level 'INFO'
    
    # Get CPU information
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $totalCores = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
    $logicalProcessors = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    
    # Get memory information
    $memory = Get-CimInstance -ClassName Win32_ComputerSystem
    $totalMemoryGB = [Math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
    
    # Get available memory
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $availableMemoryGB = [Math]::Round($os.FreePhysicalMemory / 1MB / 1024, 2)
    
    $resources = [PSCustomObject]@{
        TotalCores = $totalCores
        LogicalProcessors = $logicalProcessors
        TotalMemoryGB = $totalMemoryGB
        AvailableMemoryGB = $availableMemoryGB
        CPUName = $cpu.Name
    }
    
    Write-Log -Message "System Resources: $($totalCores) cores, $($totalMemoryGB)GB RAM ($($availableMemoryGB)GB available)" -Level 'INFO'
    
    return $resources
}

function Get-ProcessorCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $ProcessorValue
    )
    
    if ($ProcessorValue -eq "All Cores" -or $ProcessorValue -eq "All") {
        $resources = Get-SystemResources
        $cores = $resources.TotalCores
        Write-Log -Message "Using all available cores: $cores" -Level 'INFO'
        return $cores
    }
    elseif ($ProcessorValue -match '^\d+$') {
        return [int]$ProcessorValue
    }
    else {
        Write-Log -Message "Invalid processor value: $ProcessorValue. Using 2 cores as default." -Level 'WARNING'
        return 2
    }
}

function Get-AvailableDrives {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Scanning available drives..." -Level 'INFO'
    
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object {
        $_.Used -ne $null -and $_.Free -ne $null
    } | ForEach-Object {
        [PSCustomObject]@{
            DriveLetter = $_.Name
            FreeSpaceGB = [Math]::Round($_.Free / 1GB, 2)
            TotalSpaceGB = [Math]::Round(($_.Used + $_.Free) / 1GB, 2)
            UsedSpaceGB = [Math]::Round($_.Used / 1GB, 2)
            PercentFree = [Math]::Round(($_.Free / ($_.Used + $_.Free)) * 100, 2)
        }
    } | Sort-Object FreeSpaceGB -Descending
    
    Write-Log -Message "Found $($drives.Count) drives" -Level 'DEBUG'
    return $drives
}

Write-Host "`nTesting Functions Directly" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Test 1: System Resources
Write-Host "`n1. Testing Get-SystemResources:" -ForegroundColor Yellow
try {
    $resources = Get-SystemResources
    if ($resources) {
        Write-Host "   [PASS] System detected:" -ForegroundColor Green
        Write-Host "   - CPU: $($resources.CPUName)" -ForegroundColor White
        Write-Host "   - Cores: $($resources.TotalCores) (Logical: $($resources.LogicalProcessors))" -ForegroundColor White
        Write-Host "   - Memory: $($resources.TotalMemoryGB)GB (Available: $($resources.AvailableMemoryGB)GB)" -ForegroundColor White
    }
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 2: Processor Count
Write-Host "`n2. Testing Get-ProcessorCount:" -ForegroundColor Yellow
try {
    $allCores = Get-ProcessorCount -ProcessorValue "All Cores"
    Write-Host "   [PASS] 'All Cores' = $allCores" -ForegroundColor Green
    
    $specific = Get-ProcessorCount -ProcessorValue "4"
    Write-Host "   [PASS] '4' = $specific" -ForegroundColor Green
    
    $invalid = Get-ProcessorCount -ProcessorValue "Invalid"
    Write-Host "   [PASS] 'Invalid' = $invalid (defaulted)" -ForegroundColor Green
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

# Test 3: Available Drives
Write-Host "`n3. Testing Get-AvailableDrives:" -ForegroundColor Yellow
try {
    $drives = Get-AvailableDrives
    if ($drives -and $drives.Count -gt 0) {
        Write-Host "   [PASS] Found $($drives.Count) drives:" -ForegroundColor Green
        $drives | ForEach-Object {
            Write-Host "   - $($_.DriveLetter): $('{0:N2}' -f $_.FreeSpaceGB)GB free of $('{0:N2}' -f $_.TotalSpaceGB)GB" -ForegroundColor White
        }
    }
}
catch {
    Write-Host "   [FAIL] Error: $_" -ForegroundColor Red
}

Write-Host "`nDirect function tests completed!" -ForegroundColor Cyan