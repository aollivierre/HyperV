# Apply the optimization plan
$Changes = @(
    @{Name='090 - ABC Lab - Win 10 migration to Windows 11'; NewMemory=9; NewMin=[math]::Min(9, 1073741824/1GB)},
    @{Name='073 - ABC Lab - DC1 - Without WSL_20241111_083935'; NewMemory=5; NewMin=[math]::Min(5, 4294967296/1GB)},
    @{Name='089 - ABC Lab - Win 10 migration to Windows 11'; NewMemory=6; NewMin=[math]::Min(6, 1073741824/1GB)},
    @{Name='071 - Ubuntu - Docker - Syncthing_20241006_062602'; NewMemory=9.5; NewMin=[math]::Min(9.5, 4294967296/1GB)},
    @{Name='088 - Ubuntu - Claude Code - 01'; NewMemory=2; NewMin=[math]::Min(2, 4294967296/1GB)},
    @{Name='077 - ABC Lab - EHJ - NotSynced - Win 11 Client'; NewMemory=14.5; NewMin=[math]::Min(14.5, 16777216000/1GB)},
    @{Name='084 - ABC Lab - RD Gateway 03 - Server Desktop'; NewMemory=3.5; NewMin=[math]::Min(3.5, 4294967296/1GB)},
)

foreach ($Change in $Changes) {
    Write-Host "Adjusting $($Change.Name) to $($Change.NewMemory) GB..."
    Stop-VM -Name $Change.Name -Force
    Set-VMMemory -VMName $Change.Name -StartupBytes ($Change.NewMemory * 1GB) -MinimumBytes ([math]::Min($Change.NewMin, $Change.NewMemory) * 1GB)
    Start-VM -Name $Change.Name
}
