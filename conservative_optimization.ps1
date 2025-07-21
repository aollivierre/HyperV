# Conservative optimization - work within current RAM limits

Write-Host "======================================="
Write-Host "   CONSERVATIVE MEMORY OPTIMIZATION"
Write-Host "======================================="
Write-Host ""

# Get current state
$OS = Get-CimInstance Win32_OperatingSystem
$FreeRAM = [math]::Round($OS.FreePhysicalMemory/1MB, 2)
$VMs = Get-VM | Where-Object {$_.State -eq 'Running'}

Write-Host "Available free RAM: $FreeRAM GB"
Write-Host ""

# Step 1: Reduce over-provisioned VMs first
Write-Host "STEP 1: Reduce over-provisioned VMs"
Write-Host "===================================="

$Reductions = @(
    @{Name='088 - Ubuntu - Claude Code - 01'; NewMem=2; CurrentMem=4; Savings=2},
    @{Name='077 - ABC Lab - EHJ - NotSynced - Win 11 Client'; NewMem=14; CurrentMem=15.62; Savings=1.62},
    @{Name='084 - ABC Lab - RD Gateway 03 - Server Desktop'; NewMem=3.5; CurrentMem=4; Savings=0.5}
)

$TotalSavings = ($Reductions | Measure-Object -Property Savings -Sum).Sum
Write-Host "Planned savings: $TotalSavings GB"

foreach ($R in $Reductions) {
    Write-Host "- $($R.Name): $($R.CurrentMem) GB → $($R.NewMem) GB (save $($R.Savings) GB)"
}

# Step 2: Use savings to fix critical VMs
Write-Host ""
Write-Host "STEP 2: Fix critical VMs with warnings"
Write-Host "======================================"

$AvailableAfterReductions = $FreeRAM + $TotalSavings
Write-Host "RAM available after reductions: $AvailableAfterReductions GB"
Write-Host ""

$CriticalFixes = @(
    @{Name='071 - Ubuntu - Docker - Syncthing_20241006_062602'; Current=6.19; Need=9; Increase=2.81},
    @{Name='073 - ABC Lab - DC1 - Without WSL_20241111_083935'; Current=4; Need=5; Increase=1},
    @{Name='089 - ABC Lab - Win 10 migration to Windows 11'; Current=3.75; Need=5; Increase=1.25},
    @{Name='090 - ABC Lab - Win 10 migration to Windows 11'; Current=5.78; Need=8; Increase=2.22}
)

$TotalNeeded = ($CriticalFixes | Measure-Object -Property Increase -Sum).Sum
Write-Host "Total RAM needed for fixes: $TotalNeeded GB"

if ($TotalNeeded -le $AvailableAfterReductions) {
    Write-Host "✓ All critical VMs can be fixed!" -ForegroundColor Green
}
else {
    Write-Host "⚠ Can only partially fix critical VMs" -ForegroundColor Yellow
    Write-Host "  Prioritizing based on severity..."
}

# Generate the commands
Write-Host ""
Write-Host "COMMANDS TO EXECUTE:"
Write-Host "==================="
Write-Host ""

# First do reductions
Write-Host "# Step 1: Reduce over-provisioned VMs"
foreach ($R in $Reductions) {
    Write-Host "Stop-VM -Name '$($R.Name)' -Force"
    Write-Host "Set-VMMemory -VMName '$($R.Name)' -StartupBytes $($R.NewMem)GB -MinimumBytes $([math]::Min($R.NewMem, 4))GB"
    Write-Host "Start-VM -Name '$($R.Name)'"
    Write-Host ""
}

Write-Host "# Wait for memory to be released"
Write-Host "Start-Sleep -Seconds 30"
Write-Host ""

Write-Host "# Step 2: Increase memory for critical VMs"
$Budget = $AvailableAfterReductions
foreach ($C in $CriticalFixes | Sort-Object Increase) {
    if ($C.Increase -le $Budget) {
        Write-Host "Stop-VM -Name '$($C.Name)' -Force"
        Write-Host "Set-VMMemory -VMName '$($C.Name)' -StartupBytes $($C.Need)GB"
        Write-Host "Start-VM -Name '$($C.Name)'"
        Write-Host ""
        $Budget -= $C.Increase
    }
}

Write-Host ""
Write-Host "Remaining free RAM after optimization: ~$([math]::Round($Budget, 2)) GB"