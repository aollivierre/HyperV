#create a script to do auto MDM enrollment via registry key 
# $script = {
#     $registryPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
#     $registryName = "MDMEnrollmentID"
#     $registryValue = "https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc"
#     New-ItemProperty -Path $registryPath -Name $registryName -Value $registryValue -PropertyType String -Force
# }
# 
# # Run the script on the remote VM
# Invoke-Command -ComputerName $DestinationVMName -Credential $credentials -ScriptBlock $script
# 