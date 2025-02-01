# Script to audit all versions of .NET installed
# Create an empty array to store results
$results = @()

# Check .NET Framework versions through Registry
Write-Host "`n=== Checking .NET Framework Versions ===" -ForegroundColor Cyan
$frameworks = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP" -Recurse |
    Get-ItemProperty -Name Version, Release -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^(?!S)\p{L}'} |
    Select-Object @{Name="Component"; Expression={$_.PSChildName}}, Version, Release

foreach ($framework in $frameworks) {
    # Convert release number to version for .NET 4.5 and later
    if ($framework.Release) {
        $version = switch ($framework.Release) {
            378389 { ".NET Framework 4.5" }
            378675 { ".NET Framework 4.5.1" }
            378758 { ".NET Framework 4.5.1" }
            379893 { ".NET Framework 4.5.2" }
            393295 { ".NET Framework 4.6" }
            393297 { ".NET Framework 4.6" }
            394254 { ".NET Framework 4.6.1" }
            394271 { ".NET Framework 4.6.1" }
            394802 { ".NET Framework 4.6.2" }
            394806 { ".NET Framework 4.6.2" }
            460798 { ".NET Framework 4.7" }
            460805 { ".NET Framework 4.7" }
            461308 { ".NET Framework 4.7.1" }
            461310 { ".NET Framework 4.7.1" }
            461808 { ".NET Framework 4.7.2" }
            461814 { ".NET Framework 4.7.2" }
            528040 { ".NET Framework 4.8" }
            528049 { ".NET Framework 4.8" }
            533320 { ".NET Framework 4.8.1" }
            533325 { ".NET Framework 4.8.1" }
            default { "Version based on release number $($framework.Release)" }
        }
        $results += [PSCustomObject]@{
            Type = ".NET Framework"
            Name = $framework.Component
            Version = $version
            BuildVersion = $framework.Version
        }
    } else {
        $results += [PSCustomObject]@{
            Type = ".NET Framework"
            Name = $framework.Component
            Version = $framework.Version
            BuildVersion = $framework.Version
        }
    }
}

# Check .NET Core/.NET 5+ versions
Write-Host "`n=== Checking .NET Core and .NET 5+ Versions ===" -ForegroundColor Cyan
$dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnetCommand) {
    $sdks = dotnet --list-sdks
    $runtimes = dotnet --list-runtimes

    foreach ($sdk in $sdks) {
        $sdkVersion = ($sdk -split " ")[0]
        $results += [PSCustomObject]@{
            Type = ".NET SDK"
            Name = "SDK"
            Version = $sdkVersion
            BuildVersion = $sdkVersion
        }
    }

    foreach ($runtime in $runtimes) {
        if ($runtime -match "Microsoft\.NETCore\.App") {
            $runtimeVersion = ($runtime -split " ")[1]
            $results += [PSCustomObject]@{
                Type = ".NET Runtime"
                Name = "Core/Modern Runtime"
                Version = $runtimeVersion
                BuildVersion = $runtimeVersion
            }
        }
        if ($runtime -match "Microsoft\.AspNetCore\.App") {
            $runtimeVersion = ($runtime -split " ")[1]
            $results += [PSCustomObject]@{
                Type = "ASP.NET Runtime"
                Name = "ASP.NET Runtime"
                Version = $runtimeVersion
                BuildVersion = $runtimeVersion
            }
        }
        if ($runtime -match "Microsoft\.WindowsDesktop\.App") {
            $runtimeVersion = ($runtime -split " ")[1]
            $results += [PSCustomObject]@{
                Type = "Windows Desktop Runtime"
                Name = "Windows Desktop Runtime"
                Version = $runtimeVersion
                BuildVersion = $runtimeVersion
            }
        }
    }
} else {
    Write-Warning "dotnet command not found. Unable to check .NET Core/.NET 5+ versions."
}

# Display results in a formatted table
Write-Host "`n=== .NET Versions Installed ===" -ForegroundColor Green
$results | Format-Table -AutoSize -Property Type, Name, Version, BuildVersion

# Export results to CSV if needed
$results | Export-Csv -Path ".\DotNetVersions.csv" -NoTypeInformation
Write-Host "`nResults have been exported to DotNetVersions.csv in the current directory." -ForegroundColor Yellow