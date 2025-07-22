$scriptPath = "$PSScriptRoot\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v3-Refactored-CLEANED.ps1"
$errors = @()
$tokens = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)

if ($errors.Count -gt 0) {
    Write-Host "Syntax errors found:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "Line $($err.Token.StartLine): $($err.Message)" -ForegroundColor Red
        Write-Host "Near: $($err.Token.Content)" -ForegroundColor Yellow
    }
} else {
    Write-Host "No syntax errors found!" -ForegroundColor Green
}