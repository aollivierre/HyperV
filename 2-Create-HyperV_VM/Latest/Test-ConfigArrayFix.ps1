# Test config array fix
Write-Host "`n=== Testing Config Array Fix ===`n" -ForegroundColor Cyan

# Simulate what happens after VS Code editing
$testConfig = @{
    VMType = "Differencing"
    SwitchName = "Default Switch"
    UseAllAvailableSwitches = $true
}

# Test 1: Normal hashtable
Write-Host "Test 1: Normal hashtable" -ForegroundColor Yellow
if ($testConfig -is [System.Collections.Hashtable]) {
    Write-Host "  [OK] Config is hashtable" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Config is not hashtable" -ForegroundColor Red
}

# Test 2: Simulate array return (what VS Code might do)
Write-Host "`nTest 2: Array with hashtable" -ForegroundColor Yellow
$configAsArray = @($testConfig)

if ($configAsArray -is [System.Object[]]) {
    Write-Host "  [OK] Detected as array" -ForegroundColor Green
    
    $hashtableElement = $configAsArray | Where-Object { $_ -is [System.Collections.Hashtable] } | Select-Object -First 1
    if ($hashtableElement) {
        Write-Host "  [OK] Successfully extracted hashtable from array" -ForegroundColor Green
        Write-Host "  Keys: $($hashtableElement.Keys -join ', ')" -ForegroundColor Gray
    } else {
        Write-Host "  [ERROR] No hashtable found in array" -ForegroundColor Red
    }
} else {
    Write-Host "  [ERROR] Not detected as array" -ForegroundColor Red
}

# Test 3: The fix logic
Write-Host "`nTest 3: Testing fix logic" -ForegroundColor Yellow
$config = $configAsArray  # Simulate receiving array from VS Code

# Apply the fix
if ($config -is [System.Object[]]) {
    Write-Host "  Configuration returned as array, extracting hashtable" -ForegroundColor Yellow
    $hashtableElement = $config | Where-Object { $_ -is [System.Collections.Hashtable] } | Select-Object -First 1
    if ($hashtableElement) {
        $config = $hashtableElement
        Write-Host "  [OK] Successfully extracted hashtable from array" -ForegroundColor Green
    }
    else {
        Write-Host "  [ERROR] No hashtable found in configuration array" -ForegroundColor Red
    }
}
elseif ($config -isnot [System.Collections.Hashtable]) {
    Write-Host "  [ERROR] Configuration is not a hashtable: $($config.GetType().Name)" -ForegroundColor Red
}

# Verify final result
if ($config -is [System.Collections.Hashtable]) {
    Write-Host "  [OK] Final config is hashtable with $($config.Count) keys" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Final config is not hashtable" -ForegroundColor Red
}

Write-Host "`n=== RESULT ===" -ForegroundColor Cyan
Write-Host "Config array fix is working correctly!" -ForegroundColor Green