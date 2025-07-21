# Subnet Range Validation Script
# Run as Administrator

$rangesToTest = @(
    "172.20.1.1",    # Outside standard private range
    "172.33.1.1",    # Well outside standard private range
    "192.169.1.1",   # Just outside 192.168.x.x
    "10.99.99.1",    # Unusual 10.x.x.x range
    "203.0.113.1"    # TEST-NET-3 (RFC 5737)
)

Write-Host "Testing multiple IP ranges to find one that stays local..." -ForegroundColor Cyan
Write-Host "Looking for addresses that DON'T route to the internet" -ForegroundColor Yellow

foreach ($ip in $rangesToTest) {
    Write-Host "`nTesting $ip..." -ForegroundColor Cyan
    
    # Try tracert with limited hops to see routing path
    Write-Host "Running tracert with max 3 hops:" -ForegroundColor Cyan
    $tracert = tracert -d -h 3 $ip 2>&1 | Out-String
    
    # Analyze if it's trying to route through default gateway
    if ($tracert -match "192.168.100.254") {
        Write-Host "$ip - Routes through default gateway" -ForegroundColor Red
    } else {
        Write-Host "$ip - Likely stays local" -ForegroundColor Green
    }
    
    # Show first few lines of tracert
    $tracert -split "`n" | Select-Object -First 5 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
}

Write-Host "`nBasic Network Properties:" -ForegroundColor Cyan
$adapter = Get-NetAdapter | Where-Object { $_.Name -like "*SecondaryNetwork*" }
$switchInfo = Get-VMSwitch | Where-Object { $_.Name -eq "SecondaryNetwork" }

Write-Host "SecondaryNetwork adapter index: $($adapter.ifIndex)" -ForegroundColor Cyan
Write-Host "SecondaryNetwork switch type: $($switchInfo.SwitchType)" -ForegroundColor Cyan

Write-Host "`nAfter reviewing the results, select a subnet range that stays local." -ForegroundColor Yellow