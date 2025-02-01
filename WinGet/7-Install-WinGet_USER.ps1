$hasPackageManager = Get-AppPackage -name 'Microsoft.DesktopAppInstaller'
if (!$hasPackageManager -or [version]$hasPackageManager.Version -lt [version]"1.10.0.0") {
    "Installing winget Dependencies"
    Add-AppxPackage -Path 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx'

    # Install-Package Microsoft.UI.Xaml -Version 2.8.2

    # Register-PackageSource -provider NuGet -name nugetRepository -location https://www.nuget.org/api/v2
    # Install-Package Microsoft.UI.Xaml

    # #download and install UI XAML dependencies
    # $releases_url_UI_XAML = 'https://api.github.com/microsoft/microsoft-ui-xaml/releases/latest'

    # [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # $releases_UI_XAML = Invoke-RestMethod -uri $releases_url_UI_XAML
    # $latestRelease_UI_XAML = $releases_UI_XAML.assets | Where-Object { $_.browser_download_url.EndsWith('msixbundle') } | Select-Object -First 1

    # "Installing UI_XAML from $($latestRelease_UI_XAML.browser_download_url)"
    # Add-AppxPackage -Path $latestRelease_UI_XAML.browser_download_url


    #download and WINGET
    $releases_url = 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
    # $releases_url = 'https://api.github.com/PSAppDeployToolkit/PSAppDeployToolkit/releases/latest'
    $releases_url = 'https://api.github.com/repos/PSAppDeployToolkit/PSAppDeployToolkit/releases/latest'

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $releases = Invoke-RestMethod -uri $releases_url
    $latestRelease = $releases.assets | Where-Object { $_.browser_download_url.EndsWith('msixbundle') } | Select-Object -First 1

    "Installing winget from $($latestRelease.browser_download_url)"
    Add-AppxPackage -Path $latestRelease.browser_download_url
}
else {
    "winget already installed"
}
#### Creating settings.json #####

if ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
        $SettingsPath = "$Env:windir\system32\config\systemprofile\AppData\Local\Microsoft\WinGet\Settings\settings.json"
    }else{
        $SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
    }
    if (Test-Path $SettingsPath){
        $ConfigFile = Get-Content -Path $SettingsPath | Where-Object {$_ -notmatch '//'} | ConvertFrom-Json
    }
    if (!$ConfigFile){
        $ConfigFile = @{}
    }
    if ($ConfigFile.installBehavior.preferences.scope){
        $ConfigFile.installBehavior.preferences.scope = "Machine"
    }else {
        Add-Member -InputObject $ConfigFile -MemberType NoteProperty -Name 'installBehavior' -Value $(
            New-Object PSObject -Property $(@{preferences = $(
                    New-Object PSObject -Property $(@{scope = "Machine"}))
            })
        ) -Force
    }
    $ConfigFile | ConvertTo-Json | Out-File $SettingsPath -Encoding utf8 -Force




#The following error

# Add-AppxPackage : Deployment failed with HRESULT: 0x80073CF3, Package failed updates, dependency or conflict validation.                                                                                                                                                       Windows cannot install package Microsoft.DesktopAppInstaller_1.19.10173.0_x64__8wekyb3d8bbwe because this package depends on a framework that could not be found. Provide the framework "Microsoft.UI.Xaml.2.7" published by "CN=Microsoft Corporation, O=Microsoft            Corporation, L=Redmond, S=Washington, C=US", with neutral or x64 processor architecture and minimum version 7.2109.13004.0, along with this package to install. The frameworks with name "Microsoft.UI.Xaml.2.7" currently installed are: {}                                   NOTE: For additional information, look for [ActivityId] 54445850-4424-0008-7d6e-44542444d901 in the Event Log or use the command line Get-AppPackageLog -ActivityID 54445850-4424-0008-7d6e-44542444d901                                                                       At line:11 char:5                                                                                                                                                                                                                                                              +     Add-AppxPackage -Path $latestRelease.browser_download_url                                                                                                                                                                                                                +     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~                                                                                                                                                                                                                    + CategoryInfo          : WriteError: (https://github....bbwe.msixbundle:String) [Add-AppxPackage], IOException
#     + FullyQualifiedErrorId : DeploymentError,Microsoft.Windows.Appx.PackageManager.Commands.AddAppxPackageCommand



# Add-AppxPackage -register "C:\Program Files\WindowsApps\Microsoft.UI.Xaml.2.7_x64__8wekyb3d8bbwe\AppxManifest.xml" -DependencyPath "C:\Program Files\WindowsApps\Microsoft.UI.Xaml.2.7_x64__8wekyb3d8bbwe\Dependencies\x64\Microsoft.UI.Xaml.2.7_7.2109.13004.0_neutral__8wekyb3d8bbwe\AppxMetadata\AppxBundleManifest.xml"
