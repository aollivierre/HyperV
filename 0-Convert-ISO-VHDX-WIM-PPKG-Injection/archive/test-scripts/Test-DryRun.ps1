# Test script to verify the graceful handling logic
param(
    [string]$TestScenario = "1"
)

Write-Host "Testing Create-VHDX-Working.ps1 - Dry Run" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

switch ($TestScenario) {
    "1" {
        Write-Host "`nScenario 1: Missing ISO file" -ForegroundColor Yellow
        Write-Host "Expected: Should prompt for valid ISO path" -ForegroundColor Gray
        Write-Host "`nTo test: Run the script and when prompted, enter: C:\code\ISO\Windows10.iso" -ForegroundColor Green
        Write-Host "`nCommand to run:" -ForegroundColor Yellow
        Write-Host ".\Create-VHDX-Working.ps1 -ISOPath 'C:\fake\nonexistent.iso'" -ForegroundColor White
    }
    
    "2" {
        Write-Host "`nScenario 2: Invalid drive letter" -ForegroundColor Yellow
        Write-Host "Expected: Should show available drives and prompt for valid path" -ForegroundColor Gray
        Write-Host "`nAvailable drives on this system:" -ForegroundColor Green
        Get-PSDrive -PSProvider FileSystem | Format-Table Name, Used, Free
        Write-Host "`nCommand to run:" -ForegroundColor Yellow
        Write-Host ".\Create-VHDX-Working.ps1 -OutputDir 'Q:\InvalidDrive\test'" -ForegroundColor White
    }
    
    "3" {
        Write-Host "`nScenario 3: Check available drive letters" -ForegroundColor Yellow
        $used = (Get-PSDrive -PSProvider FileSystem).Name
        $all = 67..90 | ForEach-Object { [char]$_ }
        $available = $all | Where-Object { $_ -notin $used }
        
        Write-Host "Used letters: $($used -join ', ')" -ForegroundColor Red
        Write-Host "Available letters: $($available -join ', ')" -ForegroundColor Green
        Write-Host "Count available: $($available.Count)" -ForegroundColor Cyan
        
        if ($available.Count -lt 2) {
            Write-Host "`nWARNING: Not enough drive letters available!" -ForegroundColor Red
        } else {
            Write-Host "`nSufficient drive letters available for VHDX creation" -ForegroundColor Green
        }
    }
    
    "4" {
        Write-Host "`nScenario 4: Disk space check" -ForegroundColor Yellow
        Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 } | ForEach-Object {
            $freeGB = [math]::Round($_.Free / 1GB, 2)
            $usedGB = [math]::Round($_.Used / 1GB, 2)
            $percentFree = [math]::Round(($_.Free / ($_.Used + $_.Free)) * 100, 1)
            
            Write-Host "`nDrive $($_.Name):" -ForegroundColor Cyan
            Write-Host "  Free: $freeGB GB ($percentFree%)"
            Write-Host "  Used: $usedGB GB"
            
            if ($freeGB -lt 20) {
                Write-Host "  WARNING: Low disk space!" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`nTo test all scenarios, run:" -ForegroundColor Yellow
Write-Host "1..4 | ForEach-Object { .\Test-DryRun.ps1 -TestScenario `$_ }" -ForegroundColor White