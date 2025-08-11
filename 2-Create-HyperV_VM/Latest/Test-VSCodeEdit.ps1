# Test VS Code editing workflow
Write-Host "`n=== Testing VS Code Edit Fix ===`n" -ForegroundColor Cyan

# Create a test config file
$testConfigPath = "D:\Code\HyperV\2-Create-HyperV_VM\Latest\test-config-edit.psd1"

@'
@{
    TestValue = "Original"
    Counter = 1
}
'@ | Out-File -FilePath $testConfigPath -Encoding UTF8

Write-Host "Created test config with initial values:" -ForegroundColor Yellow
$config = Import-PowerShellDataFile -Path $testConfigPath
$config | Format-Table -AutoSize

# Try VS Code if available
$vscodePath = Get-Command code -ErrorAction SilentlyContinue
if ($vscodePath) {
    Write-Host "`nOpening configuration in VS Code..." -ForegroundColor Yellow
    Write-Host "Please edit the file and save it, then close VS Code or the file tab." -ForegroundColor Yellow
    Write-Host "The script will wait for you to finish editing." -ForegroundColor Yellow
    
    # Get initial file modification time
    $initialModTime = (Get-Item $testConfigPath).LastWriteTime
    
    # Open VS Code
    Start-Process code -ArgumentList "`"$testConfigPath`""
    
    # Wait for user to indicate they're done
    Write-Host "`nPress Enter when you have finished editing and saved the file..." -ForegroundColor Cyan
    Read-Host
    
    # Check if file was actually modified
    $currentModTime = (Get-Item $testConfigPath).LastWriteTime
    if ($currentModTime -gt $initialModTime) {
        Write-Host "File was modified. Reloading configuration..." -ForegroundColor Green
        
        # Reload and show new values
        $newConfig = Import-PowerShellDataFile -Path $testConfigPath
        Write-Host "`nNew configuration values:" -ForegroundColor Green
        $newConfig | Format-Table -AutoSize
        
        Write-Host "`nSUCCESS: VS Code editing workflow works correctly!" -ForegroundColor Green
    }
    else {
        Write-Host "File was not modified." -ForegroundColor Yellow
    }
}
else {
    Write-Host "VS Code not found. Skipping test." -ForegroundColor Yellow
}

# Clean up
Remove-Item -Path $testConfigPath -Force -ErrorAction SilentlyContinue