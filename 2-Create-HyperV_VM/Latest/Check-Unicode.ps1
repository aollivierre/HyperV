$content = Get-Content "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1"
$lineNum = 0
foreach ($line in $content) {
    $lineNum++
    if ($line -match '[^\x00-\x7F]') {
        Write-Host "Line $lineNum`: $line" -ForegroundColor Yellow
    }
}