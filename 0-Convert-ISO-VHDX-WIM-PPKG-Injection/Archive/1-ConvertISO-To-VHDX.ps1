# requires 5.1

# Define the parameters for splatting
# $params = @{
#     SourcePath             = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"  # Specify the path to your ISO file
#     VHDPath                = "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023.VHDX" # Specify the desired output path for the VHDX file
#     VHDPartitionStyle      = "GPT"                         # Set partition style to GPT
#     RemoteDesktopEnable    = $true                         # Enable Remote Desktop Protocol
#     VHDFormat              = "VHDX"                        # Specify VHDX format
#     SizeBytes              = 50GB                          # Specify the size, adjust as needed
#     Edition                = "Professional"                 # Specify the edition of Windows you're deploying, if applicable
# }

# Check if the Convert-WindowsImage script is available
# $scriptPath = "D:\Code\GitHub\CB\CB\Hyper-V\0-Convert-ISO-to-VHDX\0-Convert-ISO-to-VHDX.ps1"
$scriptPath = "D:\Code\GitHub\CB\CB\Hyper-V\0-Convert-ISO-to-VHDX\0-Convert-WindowsImage.ps1"
if (Test-Path $scriptPath) {
    # Dot source the script to make its functions available in the current session
    # . $scriptPath

    # Call the function with the splatted parameters
    # Convert-WindowsImage @params

    Set-Location "E:\Code\CB\Hyper-V\0-Convert-ISO-to-VHDX"

    # .\Convert-WindowsImage.ps1 -SourcePath "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso" -VHDPath "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023.VHDX" -VHDPartitionStyle "GPT" -RemoteDesktopEnable:$true -VHDFormat "VHDX" -SizeBytes 50GB -Edition "Professional"
    # .\Convert-WindowsImage.ps1 -SourcePath "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso" -VHDPath "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023-100GB-unattend-Professional.VHDX" -VHDPartitionStyle "GPT" -RemoteDesktopEnable:$false -VHDFormat "VHDX" -SizeBytes 100GB -Edition "Professional"



    # Define the parameters in a hashtable
    $params = @{
        # SourcePath          = "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso"
        SourcePath          = "D:\VM\Setup\ISO\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024.iso"
        VHDPath             = "D:\VM\Setup\VHDX\Windows_SERVER_2022_EVAL_x64FRE_en-us-May-17-2024-100GB.VHDX"
        VHDPartitionStyle   = "GPT"
        RemoteDesktopEnable = $false
        VHDFormat           = "VHDX"
        SizeBytes           = 100GB  # Make sure this is a string or converted properly
        # Edition             = "Professional"
        Edition             = "ServerDataCenterEval"
        UnattendPath        = "D:\Code\GitHub\CB\CB\Hyper-V\0-Convert-ISO-to-VHDX\Unattend\unattend.xml"
    }

    # Call the script with the splatting operator
    .\0-Convert-WindowsImage.ps1 @params




    # .\Convert-WindowsImage.ps1 -SourcePath "D:\VM\Setup\ISO\Win11_23H2_English_x64_Nov_17_2023.iso" -VHDPath "D:\VM\Setup\VHDX\Win11_23H2_English_x64_Nov_17_2023.VHDX" -VHDPartitionStyle "GPT" -VHDFormat "VHDX" -SizeBytes 50GB


}
else {
    Write-Error "Convert-WindowsImage script not found at path: $scriptPath"
}