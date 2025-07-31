# End-to-end test with the main script
Write-Host "`n=== End-to-End Multi-NIC Test ===" -ForegroundColor Cyan
Write-Host "This will create a real VM using the main script" -ForegroundColor Yellow

# Create a test config that explicitly enables multi-NIC
$testConfig = @"
@{
    # VM Type
    VMType               = "Standard"
    
    # Network - Enable multi-NIC
    SwitchName           = "Default Switch"
    UseAllAvailableSwitches = `$true  # This should add all switches
    
    # Basic settings
    VMNamePrefixFormat   = "{0:D3} - TEST - Multi-NIC EndToEnd"
    VMPath               = "D:\VM"
    InstallMediaPath     = "D:\VM\Setup\ISO\Win11_24H2_English_x64_Oct16_2024.iso"
    
    # Memory
    MemoryStartupBytes   = "2GB"
    MemoryMinimumBytes   = "1GB" 
    MemoryMaximumBytes   = "4GB"
    
    # Other settings
    Generation           = 2
    ProcessorCount       = 2
    AutoStartVM          = `$false
    AutoConnectVM        = `$false
}
"@

$configPath = "D:\Code\HyperV\2-Create-HyperV_VM\Latest\test-endtoend-config.psd1"
Set-Content -Path $configPath -Value $testConfig

Write-Host "`nConfig created at: $configPath" -ForegroundColor Green
Write-Host "Running main script with smart defaults..." -ForegroundColor Yellow

# Run the main script with smart defaults to avoid prompts
& "D:\Code\HyperV\2-Create-HyperV_VM\Latest\2-Create-HyperV_VM9-withlogging-Differencing-Windows-ALPHA-v5-SmartDefaults.ps1" `
    -UseSmartDefaults `
    -AutoSelectDrive

# Clean up config
Remove-Item -Path $configPath -Force -ErrorAction SilentlyContinue