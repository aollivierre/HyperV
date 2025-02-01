# Script to enable TLS 1.2 for Microsoft Entra Connect
# Must be run as Administrator

function Write-SectionHeader {
    param($Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
    Write-Host ("=" * (7 + $Message.Length)) -ForegroundColor Cyan
}

function Get-TLS12Status {
    # Function to check current TLS 1.2 settings
    $regSettings = @()
    
    $paths = @{
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' = @('SystemDefaultTlsVersions', 'SchUseStrongCrypto')
        'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' = @('SystemDefaultTlsVersions', 'SchUseStrongCrypto')
        'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' = @('Enabled', 'DisabledByDefault')
        'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' = @('Enabled', 'DisabledByDefault')
    }

    foreach ($path in $paths.Keys) {
        foreach ($name in $paths[$path]) {
            $regItem = Get-ItemProperty -Path $path -Name $name -ErrorAction Ignore
            $output = [PSCustomObject]@{
                Path = $path
                Name = $name
                Value = if ($regItem -eq $null) { "Not Found" } else { $regItem.$name }
            }
            $regSettings += $output
        }
    }
    return $regSettings
}

try {
    Write-SectionHeader "Checking current TLS 1.2 settings"
    $beforeSettings = Get-TLS12Status
    Write-Host "Current TLS 1.2 settings:" -ForegroundColor Yellow
    $beforeSettings | Format-Table -AutoSize

    Write-SectionHeader "Enabling TLS 1.2"
    
    # .NET Framework 64-bit
    if (-not (Test-Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319')) {
        New-Item 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
    }
    $params = @{
        Path = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
        Name = 'SystemDefaultTlsVersions'
        Value = 1
        PropertyType = 'DWord'
        Force = $true
    }
    New-ItemProperty @params | Out-Null

    $params.Name = 'SchUseStrongCrypto'
    New-ItemProperty @params | Out-Null

    # .NET Framework 32-bit
    if (-not (Test-Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319')) {
        New-Item 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319' -Force | Out-Null
    }
    $params.Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319'
    $params.Name = 'SystemDefaultTlsVersions'
    New-ItemProperty @params | Out-Null

    $params.Name = 'SchUseStrongCrypto'
    New-ItemProperty @params | Out-Null

    # TLS 1.2 Server Settings
    if (-not (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server')) {
        New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Force | Out-Null
    }
    $params.Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
    $params.Name = 'Enabled'
    New-ItemProperty @params | Out-Null

    $params.Name = 'DisabledByDefault'
    $params.Value = 0
    New-ItemProperty @params | Out-Null

    # TLS 1.2 Client Settings
    if (-not (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client')) {
        New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Force | Out-Null
    }
    $params.Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
    $params.Name = 'Enabled'
    $params.Value = 1
    New-ItemProperty @params | Out-Null

    $params.Name = 'DisabledByDefault'
    $params.Value = 0
    New-ItemProperty @params | Out-Null

    Write-SectionHeader "Verifying new TLS 1.2 settings"
    $afterSettings = Get-TLS12Status
    Write-Host "New TLS 1.2 settings:" -ForegroundColor Green
    $afterSettings | Format-Table -AutoSize

    Write-Host "`nTLS 1.2 has been successfully enabled!" -ForegroundColor Green
    Write-Host "`nIMPORTANT: You must restart the Windows Server for the changes to take effect." -ForegroundColor Yellow
    
    $restart = Read-Host "`nWould you like to restart the server now? (yes/no)"
    if ($restart -eq 'yes') {
        Write-Host "`nRestarting server in 10 seconds..." -ForegroundColor Red
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
}
catch {
    Write-Error "An error occurred while configuring TLS 1.2: $_"
    exit 1
}