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
        Write-Output "Mounting ISO: $IsoPath"
        $mountResult = Mount-DiskImage -ImagePath $IsoPath -ErrorAction Stop
        $volume = Get-Volume -DiskImage $mountResult
        return $volume.DriveLetter
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
        [string]$IsoDriveLetter,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    try {
        if (-Not (Test-Path -Path $WorkingDirectory)) {
            Write-Output "Creating working directory: $WorkingDirectory"
            New-Item -ItemType Directory -Path $WorkingDirectory -Force
        }

        Write-Output "Copying contents from ISO to working directory"
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
This function copies a specified PPKG file to the 'Sources\Provisioning' directory within the working directory.

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
        $provisioningDirectory = Join-Path -Path $WorkingDirectory -ChildPath "Sources\Provisioning"
        if (-Not (Test-Path -Path $provisioningDirectory)) {
            Write-Output "Creating Provisioning directory: $provisioningDirectory"
            New-Item -ItemType Directory -Path $provisioningDirectory -Force
        }

        Write-Output "Copying PPKG to Provisioning directory"
        Copy-Item -Path $PpkgPath -Destination $provisioningDirectory -Force -ErrorAction Stop
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

.EXAMPLE
Create-NewIso -WorkingDirectory "C:\ISO_Working_Dir" -OutputIsoPath "C:\path\to\new_windows11_with_ppkg.iso"
#>

function Create-NewIso {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OutputIsoPath
    )

    try {
        Write-Output "Creating new ISO with PPKG"
        $oscdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
        if (-Not (Test-Path -Path $oscdimgPath)) {
            Write-Error "oscdimg.exe not found. Ensure Windows ADK is installed."
            throw "oscdimg.exe not found."
        }

        # Adjust the oscdimg options to avoid conflicts
        $bootSectorFile = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\Etfsboot.com"
        if (-Not (Test-Path -Path $bootSectorFile)) {
            Write-Error "Boot sector file (Etfsboot.com) not found. Ensure Windows ADK is installed."
            throw "Boot sector file not found."
        }

        & $oscdimgPath -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$bootSectorFile"#pEF,e,b"$bootSectorFile" $WorkingDirectory $OutputIsoPath -ErrorAction Stop
    } catch {
        Write-Error "Failed to create new ISO. $_"
        throw
    }

    Write-Output "New ISO created successfully: $OutputIsoPath"
}

<#
.SYNOPSIS
Creates a new Windows ISO with a Provisioning Package (PPKG) injected.

.DESCRIPTION
This function mounts a given Windows ISO, copies its contents to a working directory, injects a specified PPKG into the 'Sources\Provisioning' directory, 
and then creates a new bootable ISO with the modified contents using oscdimg.

.PARAMETER SourceIsoPath
The file path to the source Windows ISO.

.PARAMETER PpkgPath
The file path to the Provisioning Package (PPKG) to be injected.

.PARAMETER OutputIsoPath
The file path for the newly created ISO with the injected PPKG.

.PARAMETER WorkingDirectory
The directory to which the ISO contents will be copied and modified.

.EXAMPLE
$isoCreationParams = @{
    SourceIsoPath    = "C:\path\to\windows11.iso"
    PpkgPath         = "C:\path\to\your.ppkg"
    OutputIsoPath    = "C:\path\to\new_windows11_with_ppkg.iso"
    WorkingDirectory = "C:\ISO_Working_Dir"
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
        [string]$WorkingDirectory
    )

    try {
        $isoDriveLetter = Mount-Iso -IsoPath $SourceIsoPath
        Copy-IsoContents -IsoDriveLetter $isoDriveLetter -WorkingDirectory $WorkingDirectory
    } finally {
        Write-Output "Dismounting ISO: $SourceIsoPath"
        Dismount-DiskImage -ImagePath $SourceIsoPath -ErrorAction SilentlyContinue
    }

    Copy-Ppkg -PpkgPath $PpkgPath -WorkingDirectory $WorkingDirectory
    Create-NewIso -WorkingDirectory $WorkingDirectory -OutputIsoPath $OutputIsoPath
}

# Define a splat with a more descriptive name
$isoCreationParams = @{
    SourceIsoPath     = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"
    PpkgPath          = "D:\VM\Setup\PPKG\RunPSOOBEv3.ppkg"
    OutputIsoPath     = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023-PPKG.iso"
    WorkingDirectory  = "C:\ISO_Working_Dir"
}

# Call the function with the splatted parameters
New-WindowsIsoWithPpkg @isoCreationParams