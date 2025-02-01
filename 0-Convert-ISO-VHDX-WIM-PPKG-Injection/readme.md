For any one interested in running a PS Script AUTOMATICALLY right at the start of OOBE here is how to do this. I just did for Win 11 Hyper-V VM and it worked

1- Create the Setupcomplete.cmd file using the following 

#================================================
#  [PostOS] SetupComplete CMD Command Line
#================================================
Write-Host -ForegroundColor Green "Create C:\Windows\Setup\Scripts\SetupComplete.cmd"
$SetupCompleteCMD = @'
powershell.exe -Command Set-ExecutionPolicy RemoteSigned -Force
powershell.exe -Command "& {IEX (IRM oobetasks.osdcloud.ch)}"
'@
$SetupCompleteCMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\SetupComplete.cmd' -Encoding ascii -Force

2- Install Windows System Image Manager as part of ADK (Downlaod ADK from MS official site as an MSI and install the MSI which will put Windows System image manager in your start menu)
3- Open Windows System Image Manager and create a new answer file (unattend.xml)
4- Open your WIM file (if you do not have a WIM file I converted ISO to VHDX then I captured the VHDX into a WIM)
5- Add RunsynchronousCommand to phase 4 which is the specialize phase
6- in the RunsynchronousCommand path add cmd /c C:\Windows\Setup\Scripts\SetupComplete.cmd for the command path so your unattend.xml should look like this

<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="wow64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Path>cmd /c C:\Windows\Setup\Scripts\SetupComplete.cmd</Path>
                    <Order>1</Order>
                    <Description>install autopilot oobe</Description>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    <cpi:offlineImage cpi:source="wim:d:/vm/setup/wim/install.wim#Windows 11 Custom Image" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>

7- save the unattend.xml at the root of the VHDX or pass it to your ISO/WIM2VHDX script in the unttend.xml parameter here is the script https://raw.githubusercontent.com/x0nn/Convert-WindowsImage/main/Convert-WindowsImage.ps1

8- then create a new Hyper-V and use the VHDX from step 7 as a parent for a differencing disk so that way your VM boot directly into the specialize phase skipping windows install

9- in the specialize phase you will a see cmd window pop up which will run the setupcomplete.cmd specified in the unattend.xml specialize phase

10- then the VM will reboot and then come to the OOBE screen and within 15 seconds the scheduled tasks will automatically kick in and start running your PowerShell scripts

the rest is just whatever automation you want






Note:
PSADT will force to slient mode when in OOBE according to the following and my own testing even when called using ServiceUI
https://discourse.psappdeploytoolkit.com/t/detection-of-defaultuser0-oobe-or-esp-process-forces-all-deployments-to-silent-intune/4397