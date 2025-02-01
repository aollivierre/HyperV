# Clone-HyperVVM -SourceVMName "Win1022H2_Template_18_03_23_23_07_46" -DestinationVMName "MyVM_Clone" -ExportPath "D:\VM\ExportedVMs" -ImportPath "D:\VM\ImportedVMs"

Export-VM -Name "Win1022H2_Template_18_03_23_23_07_46" -Path 'D:\VM\export'
Export-VM -Name "dattormm02" -Path 'D:\VM\export'



Import-VM -Path 'D:\VM\ExportedVMs\Win1022H2Template_19-03-23_14-04-52_20230319_151857\Win1022H2Template_19-03-23_14-04-52\Virtual Machines\29E59B85-14A3-4BCE-9AA4-EDDE1C5D9546.vmcx' -Copy -GenerateNewId