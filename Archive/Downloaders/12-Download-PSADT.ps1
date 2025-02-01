#v1

$downloadUrl = "https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/releases/latest/download/PSAppDeployToolkit.zip"
$outputPath = Join-Path $env:TEMP "PSAppDeployToolkit.zip"
$extractPath = Join-Path $env:TEMP "PSAppDeployToolkit"

Start-BitsTransfer -Source $downloadUrl -Destination $outputPath

Expand-Archive -Path $outputPath -DestinationPath $extractPath

Remove-Item $outputPath




#V2


# $packageName = 'PSAppDeployToolkit'
# $wingetPath = Join-Path $env:TEMP "winget.exe"
# $psadtInstaller = "winget install -e --id=$packageName"

$releases_url = 'https://api.github.com/repos/PSAppDeployToolkit/PSAppDeployToolkit/releases/latest'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$releases = Invoke-RestMethod -uri $releases_url
$latestRelease = $releases.assets | Where-Object { $_.browser_download_url.EndsWith('.zip') } | Select-Object -First 1

"Downloading PSADT from $($latestRelease.browser_download_url)"
Invoke-WebRequest -Uri $latestRelease.browser_download_url -OutFile "$env:TEMP\PSADT.zip"

"Installing PSADT from $wingetPath"
Expand-Archive -Path "$env:TEMP\PSADT.zip" -DestinationPath "$env:ProgramFiles\WindowsPowerShell\Modules\PSAppDeployToolkit"

"Removing downloaded PSADT installer"
Remove-Item "$env:TEMP\PSADT.zip"




#v3

$releases_url = 'https://api.github.com/repos/PSAppDeployToolkit/PSAppDeployToolkit/releases/latest'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$releases = Invoke-RestMethod -uri $releases_url
$latestRelease = $releases.assets | Where-Object { $_.browser_download_url.EndsWith('.zip') } | Select-Object -First 1

$destinationPath = 'C:\code'
if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

"Downloading PSADT from $($latestRelease.browser_download_url)"
Invoke-WebRequest -Uri $latestRelease.browser_download_url -OutFile "$env:TEMP\PSADT.zip"

"Installing PSADT to $destinationPath"
Expand-Archive -Path "$env:TEMP\PSADT.zip" -DestinationPath $destinationPath

"Removing downloaded PSADT installer"
Remove-Item "$env:TEMP\PSADT.zip"



#v4


$releases_url = 'https://api.github.com/repos/PSAppDeployToolkit/PSAppDeployToolkit/releases/latest'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$releases = Invoke-RestMethod -uri $releases_url
$latestRelease = $releases.assets | Where-Object { $_.browser_download_url.EndsWith('.zip') } | Select-Object -First 1
$releaseVersion = $releases.tag_name

$destinationPath = "C:\code\PSADT\$releaseVersion"
if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

"Downloading PSADT $releaseVersion from $($latestRelease.browser_download_url)"
Invoke-WebRequest -Uri $latestRelease.browser_download_url -OutFile "$env:TEMP\PSADT.zip"

"Installing PSADT to $destinationPath"
Expand-Archive -Path "$env:TEMP\PSADT.zip" -DestinationPath $destinationPath

"Removing downloaded PSADT installer"
Remove-Item "$env:TEMP\PSADT.zip"




#v5 (latest)

$releases_url = 'https://api.github.com/repos/PSAppDeployToolkit/PSAppDeployToolkit/releases/latest'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$releases = Invoke-RestMethod -uri $releases_url
$latestRelease = $releases.assets | Where-Object { $_.browser_download_url.EndsWith('.zip') } | Select-Object -First 1
$releaseVersion = $releases.tag_name

$destinationPath = "C:\code\PSADT\$releaseVersion"
if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

"Downloading PSADT $releaseVersion from $($latestRelease.browser_download_url)"
Start-BitsTransfer -Source $latestRelease.browser_download_url -Destination "$env:TEMP\PSADT.zip"

"Installing PSADT to $destinationPath"
Expand-Archive -Path "$env:TEMP\PSADT.zip" -DestinationPath $destinationPath

"Removing downloaded PSADT installer"
Remove-Item "$env:TEMP\PSADT.zip"

