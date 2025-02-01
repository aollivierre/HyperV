# Set the package name and version
$packageName = "Microsoft.UI.Xaml"
$version = "2.8.2"

# Set the download URL
$url = "https://www.nuget.org/api/v2/package/$packageName/$version"

# Set the download path
$downloadPath = "$env:TEMP\$packageName.$version.nupkg"

# Download the package
Invoke-WebRequest -Uri $url -OutFile $downloadPath

# Extract the package contents to a temporary directory
$tempPath = "$env:TEMP\$packageName.$version"
Expand-Archive -Path $downloadPath -DestinationPath $tempPath

# Install the module from the temporary directory
$modulePath = Join-Path $tempPath "$packageName.$version\tools\$packageName"
Install-Module -Path $modulePath -Force

# Clean up the temporary files
Remove-Item $downloadPath
Remove-Item $tempPath -Recurse






#v2

$url = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.2"
$downloadPath = "$($env:USERPROFILE)\Downloads\Microsoft.UI.Xaml.2.8.2.nupkg"
$tempPath = "$($env:USERPROFILE)\Downloads\Microsoft.UI.Xaml.2.8.2"

# Download package
Invoke-WebRequest -Uri $url -OutFile $downloadPath

# Rename .nupkg to .zip
Rename-Item -Path $downloadPath -NewName ($downloadPath -replace '\.nupkg','.zip')

# Extract package to destination folder
Expand-Archive -Path $downloadPath -DestinationPath $tempPath

# Copy module to PowerShell module path
$moduleName = "Microsoft.UI.Xaml"
$modulePath = "$($env:ProgramFiles)\WindowsPowerShell\Modules\$moduleName"
Copy-Item -Path "$tempPath\tools\$moduleName" -Destination $modulePath -Recurse

# Import module
Import-Module $moduleName




#v3

# Set the URL and version number of the package to download
$url = 'https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.2'
$version = '2.8.2'

# Set the download and temporary folder paths
$downloadPath = "$env:USERPROFILE\Downloads\Microsoft.UI.Xaml.$version.nupkg"
$tempPath = "$env:USERPROFILE\AppData\Local\Temp\Microsoft.UI.Xaml.$version"

# Download the package using Start-BitsTransfer
Start-BitsTransfer -Source $url -Destination $downloadPath

# Create the temporary folder and extract the package
New-Item -ItemType Directory -Force -Path $tempPath
Expand-Archive -Path $downloadPath -DestinationPath $tempPath

# Remove the downloaded package file
Remove-Item -Path $downloadPath

# Install the module
$modulePath = Join-Path $tempPath "tools"
Install-Module -Path $modulePath -Force

# Clean up the temporary folder
Remove-Item -Path $tempPath -Recurse







#v4

$url = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.2"
$downloadPath = "$($env:USERPROFILE)\Downloads\Microsoft.UI.Xaml.2.8.2.nupkg"
$tempPath = "$($env:USERPROFILE)\Downloads\Microsoft.UI.Xaml.2.8.2"

# Download package
Invoke-WebRequest -Uri $url -OutFile $downloadPath

# Rename .nupkg to .zip
Rename-Item -Path $downloadPath -NewName ($downloadPath -replace '\.nupkg','.zip')

# Extract package to destination folder
Expand-Archive -Path ($downloadPath -replace '\.nupkg','.zip') -DestinationPath $tempPath

# Copy module to PowerShell module path
$moduleName = "Microsoft.UI.Xaml"
$modulePath = "$($env:ProgramFiles)\WindowsPowerShell\Modules\$moduleName"
Copy-Item -Path "$tempPath\tools\$moduleName" -Destination $modulePath -Recurse

# Import module
Import-Module $moduleName
