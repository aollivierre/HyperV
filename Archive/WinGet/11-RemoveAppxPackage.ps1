#Check before
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.DesktopAppInstaller"}

#remove (update with your package name extracted from )
$packageName = "Microsoft.DesktopAppInstaller_2023.118.406.0_neutral_~_8wekyb3d8bbwe"
Remove-AppxProvisionedPackage -Online -PackageName $packageName -ErrorAction Continue

#Check after
Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.DesktopAppInstaller"}


$packageName = "Microsoft.DesktopAppInstaller_2023.118.406.0_neutral_~_8wekyb3d8bbwe"
Remove-AppxPackage -Package $packageName -AllUsers -ErrorAction SilentlyContinue