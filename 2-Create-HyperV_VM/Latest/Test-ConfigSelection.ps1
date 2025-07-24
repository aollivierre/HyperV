# Quick test of config selection fix

# Test regex patterns
Write-Host "Testing regex patterns:" -ForegroundColor Cyan

$testCases = @(
    @{Input = "1"; Count = 11; Expected = $true},
    @{Input = "3"; Count = 11; Expected = $true},
    @{Input = "11"; Count = 11; Expected = $true},
    @{Input = "12"; Count = 11; Expected = $false},
    @{Input = "0"; Count = 11; Expected = $false},
    @{Input = "abc"; Count = 11; Expected = $false}
)

foreach ($test in $testCases) {
    $selection = $test.Input
    $count = $test.Count
    
    # New validation logic
    if ($selection -match '^\d+$') {
        $selectionNum = [int]$selection
        $validSelection = ($selectionNum -ge 1) -and ($selectionNum -le $count)
    } else {
        $validSelection = $false
    }
    
    $result = if ($validSelection -eq $test.Expected) { "PASS" } else { "FAIL" }
    $color = if ($result -eq "PASS") { "Green" } else { "Red" }
    
    Write-Host "[$result] Input: '$($test.Input)' (Count: $count) - Valid: $validSelection (Expected: $($test.Expected))" -ForegroundColor $color
}

Write-Host "`nAll tests completed!" -ForegroundColor Cyan