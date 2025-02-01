function Install-PowerShell7 {
    $GitHubRepo = "PowerShell/PowerShell"
    $LatestReleaseApiUrl = "https://api.github.com/repos/$GitHubRepo/releases/latest"

    try {
        # Fetch the latest release information from GitHub
        $LatestRelease = Invoke-WebRequest -Uri $LatestReleaseApiUrl -UseBasicParsing | ConvertFrom-Json

        # Determine the installer URL based on the current OS architecture
        $OSArchitecture = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
        $InstallerUrl = $null
        if ($OSArchitecture -eq '64-bit') {
            $InstallerUrl = $LatestRelease.assets | Where-Object { $_.name -match 'win-x64.msi' } | Select-Object -ExpandProperty browser_download_url
        } elseif ($OSArchitecture -eq '32-bit') {
            $InstallerUrl = $LatestRelease.assets | Where-Object { $_.name -match 'win-x86.msi' } | Select-Object -ExpandProperty browser_download_url
        } else {
            throw "Unsupported OS architecture: $OSArchitecture"
        }

        # Download the installer
        $InstallerPath = Join-Path $env:TEMP "PowerShell7Installer.msi"
        Write-Host "Downloading PowerShell 7 installer from $InstallerUrl"
        Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath

        # Install PowerShell 7
        Write-Host "Installing PowerShell 7"
        Start-Process -FilePath msiexec.exe -ArgumentList "/i", $InstallerPath, "/qn", "/norestart" -Wait

        # Clean up the installer
        Remove-Item $InstallerPath

        Write-Host "PowerShell 7 installed successfully!"
    } catch {
        Write-Warning "Error installing PowerShell 7"
        Write-Warning $_.Exception.Message
    }
}

# Usage
Install-PowerShell7
