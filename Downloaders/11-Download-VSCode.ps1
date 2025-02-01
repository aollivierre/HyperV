$downloadUrl = "https://az764295.vo.msecnd.net/stable/441438abd1ac652551dbe4d408dfcec8a499b8bf/VSCodeSetup-x64-1.75.1.exe"
$outputPath = Join-Path $env:TEMP "VSCodeSetup-x64-1.75.1.exe"

Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath

Start-Process $outputPath

Remove-Item $outputPath


#v2 works and much faster
$downloadUrl = "https://az764295.vo.msecnd.net/stable/441438abd1ac652551dbe4d408dfcec8a499b8bf/VSCodeSetup-x64-1.75.1.exe"
$outputPath = Join-Path $env:TEMP "VSCodeSetup-x64-1.75.1.exe"

Start-BitsTransfer -Source $downloadUrl -Destination $outputPath

Start-Process $outputPath

Remove-Item $outputPath