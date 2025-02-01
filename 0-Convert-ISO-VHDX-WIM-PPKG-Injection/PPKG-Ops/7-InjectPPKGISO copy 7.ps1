<#
.SYNOPSIS
Mounts a given ISO file.

.DESCRIPTION
This function mounts a specified ISO file and returns the drive letter of the mounted ISO.

.PARAMETER IsoPath
The file path to the ISO to be mounted.

.EXAMPLE
$driveLetter = Mount-Iso -IsoPath "C:\path\to\windows11.iso"
#>

function Mount-Iso {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$IsoPath
    )

    try {
        Write-Host "Mounting ISO: $IsoPath"
        $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
        $driveLetter = (Get-Volume -DiskImage $mountResult).DriveLetter
        return $driveLetter
    } catch {
        Write-Error "Failed to mount ISO. $_"
        throw
    }
}

<#
.SYNOPSIS
Copies the contents of a mounted ISO to a specified working directory.

.DESCRIPTION
This function copies all contents from the mounted ISO to the specified working directory.

.PARAMETER IsoDriveLetter
The drive letter of the mounted ISO.

.PARAMETER WorkingDirectory
The directory to which the ISO contents will be copied.

.EXAMPLE
Copy-IsoContents -IsoDriveLetter "E" -WorkingDirectory "C:\ISO_Working_Dir"
#>

function Copy-IsoContents {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [char]$IsoDriveLetter,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    try {
        if (-Not (Test-Path -Path $WorkingDirectory)) {
            Write-Host "Creating working directory: $WorkingDirectory"
            New-Item -ItemType Directory -Path $WorkingDirectory -Force
        }

        Write-Host "Copying contents from ISO to working directory"
        Copy-Item -Path "$($IsoDriveLetter):\*" -Destination $WorkingDirectory -Recurse -Force -ErrorAction Stop
    } catch {
        Write-Error "Failed to copy ISO contents. $_"
        throw
    }
}

<#
.SYNOPSIS
Copies a Provisioning Package (PPKG) to the Provisioning directory in the working directory.

.DESCRIPTION
This function copies a specified PPKG file to the 'sources\ppkg' directory within the working directory.

.PARAMETER PpkgPath
The file path to the Provisioning Package (PPKG).

.PARAMETER WorkingDirectory
The directory to which the ISO contents have been copied and where the PPKG will be placed.

.EXAMPLE
Copy-Ppkg -PpkgPath "C:\path\to\your.ppkg" -WorkingDirectory "C:\ISO_Working_Dir"
#>

function Copy-Ppkg {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PpkgPath,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    try {
        $ppkgDirectory = Join-Path -Path $WorkingDirectory -ChildPath "sources\ppkg"
        if (-Not (Test-Path -Path $ppkgDirectory)) {
            Write-Host "Creating PPKG directory: $ppkgDirectory"
            New-Item -ItemType Directory -Path $ppkgDirectory -Force
        }

        Write-Host "Copying PPKG to PPKG directory"
        Copy-Item -Path $PpkgPath -Destination $ppkgDirectory -Force -ErrorAction Stop
    } catch {
        Write-Error "Failed to copy PPKG. $_"
        throw
    }
}

<#
.SYNOPSIS
Creates a new bootable ISO with modified contents.

.DESCRIPTION
This function creates a new bootable ISO from the contents of the specified working directory using oscdimg.

.PARAMETER WorkingDirectory
The directory containing the modified contents to be included in the new ISO.

.PARAMETER OutputIsoPath
The file path for the newly created ISO.

.PARAMETER OscdimgPath
The path to the oscdimg.exe utility.

.PARAMETER BootSectorFile
The path to the boot sector file (etfsboot.com).

.EXAMPLE
Create-NewIso -WorkingDirectory "C:\ISO_Working_Dir" -OutputIsoPath "C:\path\to\new_windows11_with_ppkg.iso" -OscdimgPath "C:\path\to\oscdimg.exe" -BootSectorFile "C:\path\to\etfsboot.com"
#>

function Create-NewIso {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OutputIsoPath,

        [Parameter(Mandatory = $true)]
        [string]$OscdimgPath,

        [Parameter(Mandatory = $true)]
        [string]$BootSectorFile
    )

    try {
        Write-Host "Creating new ISO with PPKG"
        if (-Not (Test-Path -Path $OscdimgPath)) {
            Write-Error "oscdimg.exe not found. Ensure Windows ADK is installed."
            throw "oscdimg.exe not found."
        }

        if (-Not (Test-Path -Path $BootSectorFile)) {
            Write-Error "Boot sector file (etfsboot.com) not found. Ensure Windows ADK is installed."
            throw "Boot sector file not found."
        }

        $arguments = "-m -o -u2 -udfver102 -b`"$BootSectorFile`" $WorkingDirectory $OutputIsoPath"
        Start-Process -FilePath $OscdimgPath -ArgumentList $arguments -Wait -NoNewWindow -ErrorAction Stop
    } catch {
        Write-Error "Failed to create new ISO. $_"
        throw
    }

    Write-Host "New ISO created successfully: $OutputIsoPath"
}

<#
.SYNOPSIS
Validates if the specified ISO is mounted.

.DESCRIPTION
This function checks if a specified ISO file is mounted and returns a boolean indicating its status.

.PARAMETER IsoPath
The file path to the ISO to be validated.

.EXAMPLE
$isMounted = Validate-ISOMount -IsoPath "C:\path\to\windows11.iso"
#>

function Validate-ISOMount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$IsoPath
    )

    try {
        # Check if the ISO is mounted
        $diskImage = Get-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
        if ($diskImage -and $diskImage.Attached) {
            Write-Host "ISO is mounted: $IsoPath" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "ISO is not mounted: $IsoPath" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Error "Failed to validate ISO mount. $_"
        return $false
    }
}

<#
.SYNOPSIS
Creates an autounattend.xml file for automating the OOBE phase and references the PPKG.

.DESCRIPTION
This function creates an autounattend.xml file and places it in the specified working directory.

.PARAMETER WorkingDirectory
The directory where the autounattend.xml file will be created.

.PARAMETER PpkgName
The name of the PPKG file to be referenced in the autounattend.xml.

.EXAMPLE
Create-AutounattendXml -WorkingDirectory "C:\ISO_Working_Dir" -PpkgName "RunPSOOBEv3.ppkg"
#>

function Create-AutounattendXml {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [string]$PpkgName
    )

    try {
        $autounattendPath = Join-Path -Path $WorkingDirectory -ChildPath "autounattend.xml"
        $autounattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <Reseal>
                <Mode>Audit</Mode>
            </Reseal>
        </component>
        <component name="Microsoft-Windows-Provisioning" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <Packages>
                <Package path="sources\ppkg\$PpkgName" />
            </Packages>
        </component>
    </settings>
</unattend>
"@
        $autounattendContent | Out-File -FilePath $autounattendPath -Encoding utf8
    } catch {
        Write-Error "Failed to create autounattend.xml. $_"
        throw
    }
}

<#
.SYNOPSIS
Creates a new Windows ISO with a Provisioning Package (PPKG) injected.

.DESCRIPTION
This function mounts a given Windows ISO, copies its contents to a working directory, injects a specified PPKG into the 'sources\ppkg' directory, 
creates an autounattend.xml file, and then creates a new bootable ISO with the modified contents using oscdimg.

.PARAMETER SourceIsoPath
The file path to the source Windows ISO.

.PARAMETER PpkgPath
The file path to the Provisioning Package (PPKG) to be injected.

.PARAMETER OutputIsoPath
The file path for the newly created ISO with the injected PPKG.

.PARAMETER WorkingDirectory
The directory to which the ISO contents will be copied and modified.

.PARAMETER OscdimgPath
The path to the oscdimg.exe utility.

.PARAMETER BootSectorFile
The path to the boot sector file (etfsboot.com).

.EXAMPLE
$isoCreationParams = @{
    SourceIsoPath    = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"
    PpkgPath         = "D:\VM\Setup\PPKG\RunPSOOBEv3.ppkg"
    OutputIsoPath    = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023-PPKG.iso"
    WorkingDirectory = "C:\ISO_Working_Dir"
    OscdimgPath      = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    BootSectorFile   = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\etfsboot.com"
}
New-WindowsIsoWithPpkg @isoCreationParams
#>

function New-WindowsIsoWithPpkg {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceIsoPath,

        [Parameter(Mandatory = $true)]
        [string]$PpkgPath,

        [Parameter(Mandatory = $true)]
        [string]$OutputIsoPath,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OscdimgPath,

        [Parameter(Mandatory = $true)]
        [string]$BootSectorFile
    )

    try {
        if (Validate-ISOMount -IsoPath $SourceIsoPath) {
            throw "The ISO file is already mounted. Please dismount it before proceeding."
        }

        $isoDriveLetter = Mount-Iso -IsoPath $SourceIsoPath

        if (-Not (Validate-ISOMount -IsoPath $SourceIsoPath)) {
            throw "The ISO file failed to mount."
        }

        Copy-IsoContents -IsoDriveLetter $isoDriveLetter -WorkingDirectory $WorkingDirectory
    } finally {
        Write-Host "Dismounting ISO: $SourceIsoPath"
        Dismount-DiskImage -ImagePath $SourceIsoPath -ErrorAction SilentlyContinue

        if (Validate-ISOMount -IsoPath $SourceIsoPath) {
            Write-Host "ISO file failed to dismount. Attempting again."
            Dismount-DiskImage -ImagePath $SourceIsoPath -ErrorAction SilentlyContinue
        }
    }

    Copy-Ppkg -PpkgPath $PpkgPath -WorkingDirectory $WorkingDirectory
    Create-AutounattendXml -WorkingDirectory $WorkingDirectory -PpkgName (Split-Path -Leaf $PpkgPath)
    Create-NewIso -WorkingDirectory $WorkingDirectory -OutputIsoPath $OutputIsoPath -OscdimgPath $OscdimgPath -BootSectorFile $BootSectorFile

    # Validate the new ISO
    if (-Not (Validate-ISOMount -IsoPath $OutputIsoPath)) {
        $newIsoDriveLetter = Mount-Iso -IsoPath $OutputIsoPath

        if (Validate-ISOMount -IsoPath $OutputIsoPath) {
            Write-Host "New ISO is mounted successfully: $OutputIsoPath"
            Dismount-DiskImage -ImagePath $OutputIsoPath -ErrorAction SilentlyContinue
            Write-Host "Dismounted new ISO: $OutputIsoPath"
        } else {
            Write-Error "New ISO failed to mount: $OutputIsoPath"
        }
    } else {
        Write-Error "Failed to validate the new ISO creation."
    }
}

# Define a splat with a more descriptive name
$isoCreationParams = @{
    SourceIsoPath    = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"
    PpkgPath         = "D:\VM\Setup\PPKG\RunPSOOBEv3.ppkg"
    OutputIsoPath    = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023-PPKG.iso"
    WorkingDirectory = "C:\ISO_Working_Dir"
    OscdimgPath      = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    BootSectorFile   = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\etfsboot.com"
}

# Call the function with the splatted parameters
New-WindowsIsoWithPpkg @isoCreationParams
