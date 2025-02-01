$destinationPath = "C:\code\Tools\PStools"
if (-not (Test-Path -Path $destinationPath -PathType Container)) {
    New-Item -Path $destinationPath -ItemType Directory
}

$downloadUrl = "https://download.sysinternals.com/files/PSTools.zip"
$outputFile = "$env:TEMP\PSTools.zip"

"Downloading PStools from $downloadUrl"
Start-BitsTransfer -Source $downloadUrl -Destination $outputFile

"Extracting PStools to $destinationPath"
Expand-Archive -Path $outputFile -DestinationPath $destinationPath

"Removing downloaded PStools package"
Remove-Item $outputFile



$toolsPath = "C:\code\Tools\PStools"

# Get the current PATH environment variable value
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")

# Check if the toolsPath is already in the PATH variable
if ($currentPath -notlike "*$toolsPath*") {
    # If the toolsPath is not in the PATH variable, add it
    $newPath = "$toolsPath;$currentPath"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
    Write-Host "Added $toolsPath to PATH environment variable"
} else {
    Write-Host "$toolsPath is already in PATH environment variable"
}
