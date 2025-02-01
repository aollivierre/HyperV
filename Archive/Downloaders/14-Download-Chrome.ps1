$destinationPath = "C:\code\GoogleChrome"
if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

$downloadUrl = "https://github.com/aollivierre/appgallery/raw/main/Google/Chrome/Latest/GoogleChromeStandaloneEnterprise64.msi"
$outputFile = "$env:TEMP\GoogleChromeStandaloneEnterprise64.msi"

"Downloading Google Chrome from $downloadUrl"
Start-BitsTransfer -Source $downloadUrl -Destination $outputFile

# "Installing Google Chrome to $destinationPath"
# Start-Process msiexec.exe -ArgumentList "/i $outputFile /quiet /norestart /log install.log INSTALLDIR=`"$destinationPath`"" -Wait

"Removing downloaded Google Chrome package"
Remove-Item $outputFile



#v2

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$destinationPath = Join-Path -Path $scriptRoot -ChildPath "Files"

if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

$downloadUrl = "https://github.com/aollivierre/appgallery/raw/main/Google/Chrome/Latest/GoogleChromeStandaloneEnterprise64.msi"
# $downloadUrl = "https://raw.githubusercontent.com/aollivierre/appgallery/main/Google/Chrome/Latest/GoogleChromeStandaloneEnterprise64.msi"
$outputFile = Join-Path -Path $destinationPath -ChildPath "GoogleChromeStandaloneEnterprise64.msi"

"Downloading Google Chrome from $downloadUrl"
try {
    Start-BitsTransfer -Source $downloadUrl -Destination $outputFile -ErrorAction Stop
} catch {
    Write-Error "Failed to download Google Chrome: $_"
}

"Removing downloaded Google Chrome package"
try {
    Remove-Item $outputFile -ErrorAction Stop
} catch {
    Write-Error "Failed to remove downloaded Google Chrome package: $_"
}

"Waiting for 5 seconds"
Start-Sleep -Seconds 5



#v3

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$destinationPath = Join-Path -Path $scriptRoot -ChildPath "Files"

if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

$downloadUrl = "https://github.com/aollivierre/appgallery/raw/main/Google/Chrome/Latest/GoogleChromeStandaloneEnterprise64.msi"
$outputFile = Join-Path -Path $destinationPath -ChildPath "GoogleChromeStandaloneEnterprise64.msi"

"Downloading Google Chrome from $downloadUrl"
try {
    $transferJob = Start-BitsTransfer -Source $downloadUrl -Destination $outputFile -Asynchronous
    while (($transferJob.JobState -eq 'Transferring') -or ($transferJob.JobState -eq 'Connecting')) {
        Start-Sleep -Milliseconds 500
    }
}
catch {
    Write-Error "Failed to download Google Chrome: $_"
}

if ($transferJob.JobState -eq 'Transferred') {
    "File downloaded successfully"
} else {
    "Failed to download file"
}


#v4

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$destinationPath = Join-Path -Path $scriptRoot -ChildPath "Files"

if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

$downloadUrl = "https://github.com/aollivierre/appgallery/raw/main/Google/Chrome/Latest/GoogleChromeStandaloneEnterprise64.msi"
$outputFile = Join-Path -Path $destinationPath -ChildPath "GoogleChromeStandaloneEnterprise64.msi"

"Downloading Google Chrome from $downloadUrl"
try {
    Start-BitsTransfer -Source $downloadUrl -Destination $outputFile -ErrorAction Stop

    "Waiting for download to complete"
    while ((Get-BitsTransfer -Name "Download" -ErrorAction SilentlyContinue).JobState -ne "Transferred") {
        Start-Sleep -Seconds 1
    }
} catch {
    Write-Error "Failed to download Google Chrome: $_"
}








#v5


$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$destinationPath = Join-Path -Path $scriptRoot -ChildPath "Files"

if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

$downloadUrl = "https://github.com/aollivierre/appgallery/raw/main/Google/Chrome/Latest/GoogleChromeStandaloneEnterprise64.msi"
$outputFile = Join-Path -Path $destinationPath -ChildPath "GoogleChromeStandaloneEnterprise64.msi"

"Downloading Google Chrome from $downloadUrl"
Start-BitsTransfer -Source $downloadUrl -Destination $outputFile -Asynchronous

"Waiting for download to complete"
while ((Get-ChildItem -Path $outputFile -ErrorAction SilentlyContinue).Length -lt 1) {
    Start-Sleep -Seconds 1
}

"Download complete"






#v6

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$destinationPath = Join-Path -Path $scriptRoot -ChildPath "Files"

if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

$downloadUrl = "https://github.com/aollivierre/appgallery/raw/main/Google/Chrome/Latest/GoogleChromeStandaloneEnterprise64.msi"
$outputFile = Join-Path -Path $destinationPath -ChildPath "GoogleChromeStandaloneEnterprise64.msi"

# Set the .NET Framework to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $outputFile)
    "Google Chrome downloaded to $outputFile"
}
catch {
    Write-Error "Failed to download Google Chrome: $_"
}









#v7

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$destinationPath = Join-Path -Path $scriptRoot -ChildPath "Files"

if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

$downloadUrl = "https://github.com/aollivierre/appgallery/raw/main/Google/Chrome/Latest/GoogleChromeStandaloneEnterprise64.msi"
$outputFile = Join-Path -Path $destinationPath -ChildPath "GoogleChromeStandaloneEnterprise64.msi"

# Set the .NET Framework to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    $httpClient = New-Object System.Net.Http.HttpClient
    $response = $httpClient.GetAsync($downloadUrl).Result
    $response.EnsureSuccessStatusCode()

    $outputFileStream = [System.IO.File]::OpenWrite($outputFile)
    $downloadTask = $response.Content.CopyToAsync($outputFileStream)
    $downloadTask.Wait()

    $outputFileStream.Close()

    "Google Chrome downloaded to $outputFile"
}
catch {
    Write-Error "Failed to download Google Chrome: $_"
}


