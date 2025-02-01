function Convert-ISOToVHDX {
    <#
    .SYNOPSIS
        Converts a Windows ISO file to a VHDX file using the Convert-WindowsImage script.

    .DESCRIPTION
        This function leverages the Convert-WindowsImage script to convert a specified Windows ISO file to a VHDX file. 
        The parameters for the conversion are passed as a splat for readability and maintainability.

    .PARAMETER SourcePath
        The path to the Windows ISO file.

    .PARAMETER VHDPath
        The desired output path for the VHDX file.

    .PARAMETER VHDPartitionStyle
        The partition style for the VHD (e.g., "GPT").

    .PARAMETER RemoteDesktopEnable
        Boolean value to enable or disable Remote Desktop Protocol.

    .PARAMETER VHDFormat
        The format of the VHD (e.g., "VHDX").

    .PARAMETER SizeBytes
        The size of the VHDX file.

    .PARAMETER Edition
        The edition of Windows to deploy (e.g., "Professional").

    .PARAMETER UnattendPath
        The path to the Unattend XML file for Windows setup automation.

    .EXAMPLE
        $params = @{
            SourcePath          = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"
            VHDPath             = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023.VHDX"
            VHDPartitionStyle   = "GPT"
            RemoteDesktopEnable = $true
            VHDFormat           = "VHDX"
            SizeBytes           = 50GB
            Edition             = "Professional"
            UnattendPath        = "D:\Code\GitHub\CB\CB\Hyper-V\0-Convert-ISO-to-VHDX\Unattend\unattend.xml"
        }

        Convert-ISOToVHDX @params
    #>
    [CmdletBinding()]
    param (

        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$VHDPath,

        [Parameter(Mandatory = $true)]
        [string]$VHDPartitionStyle,

        [Parameter(Mandatory = $true)]
        [bool]$RemoteDesktopEnable,

        [Parameter(Mandatory = $true)]
        [string]$VHDFormat,

        [Parameter(Mandatory = $true)]
        [string]$SizeBytes,

        [Parameter(Mandatory = $true)]
        [string]$Edition,

        [Parameter(Mandatory = $false)]
        [string]$UnattendPath
    )

    begin {
        Write-Host 'starting the ISO to VHDX conversion'
    }

    process {
        try {
            if (Test-Path $scriptPath) {
                # Unblock the script to avoid security warning
                Unblock-File -Path $scriptPath

                $params = @{
                    SourcePath          = $SourcePath
                    VHDPath             = $VHDPath
                    VHDPartitionStyle   = $VHDPartitionStyle
                    RemoteDesktopEnable = $RemoteDesktopEnable
                    VHDFormat           = $VHDFormat
                    SizeBytes           = $SizeBytes
                    Edition             = $Edition
                    UnattendPath        = $UnattendPath
                }

                & "$scriptPath" @params
                
            }
            else {
                throw "Convert-WindowsImage script not found at path: $scriptPath"
            }
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }

    end {
        Write-Verbose "Conversion process completed."
    }
}




$params = @{
    ScriptPath          = "D:\Code\CB\Hyper-V\0-Convert-ISO-VHDX-WIM-PPKG-Injection\Archive\0-Convert-WindowsImage-working-old.ps1"
    SourcePath          = "D:\VM\Setup\ISO\Win11_23H2_English_x64v2_July_04_2024.iso"
    VHDPath             = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_July_04_2024-100GB-unattend-PFW-OOEBE-tasks.VHDX"
    VHDPartitionStyle   = "GPT"
    RemoteDesktopEnable = $false
    VHDFormat           = "VHDX"
    SizeBytes           = 100GB
    Edition             = "LIST"
    UnattendPath        = "D:\Code\CB\Hyper-V\0-Convert-ISO-VHDX-WIM-PPKG-Injection\3.2-Inject-Unattend-VHDX\Unattend\unattend.xml"
}

Convert-ISOToVHDX @params