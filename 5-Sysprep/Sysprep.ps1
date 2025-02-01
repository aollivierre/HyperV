# Set-NetConnectionProfile -NetworkCategory Private     
     
# Replace 'YourUsername' and 'YourPassword' with your actual credentials
$username = "Admin-CCI"
#  $Computername = "Win1022H2Template_19-03-23_18-31-11_Pending_SysPrep_Clone_20230319_202744"
$vmIpAddress = "10.224.10.23"
$password = "Whatever Your Password is" | ConvertTo-SecureString -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password

$sysprepScript = {
    $sysprepPath = "${env:windir}\system32\sysprep\sysprep.exe"
    & $sysprepPath /generalize /shutdown /oobe
}

#  Invoke-Command -ComputerName $Computername -Credential $credentials -ScriptBlock $sysprepScript
Invoke-Command -ComputerName $vmIpAddress -Credential $credentials -ScriptBlock $sysprepScript



# If you try to run Sysprep on Windows, more than three (3) times, then you will receive the following error message "A fatal error occurred while trying to Sysprep the machine" and the following explanation message is displayed inside the sysprep error log file (setuperr.log): "Date Time, Error [0x0f0073] SYSPRP RunExternalDlls:Not running DLLs; either the machine is in an invalid state or we couldn't update the recorded state, dwRet = 31".

#ref https://www.wintips.org/fix-sysprep-fatal-error-dwret-31-machine-invalid-state-couldnt-update-recorded-state/


#Path for the Sysprep folder
# %WINDIR%\system32\sysprep

#One Liner to sysprep a machine before using it (after importing it)
& "${env:windir}\system32\sysprep\sysprep.exe" /generalize /shutdown /oobe