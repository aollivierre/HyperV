# PowerShell script to list all files and directories in D:\VM

# Define the directory to list
$directory = "D:\VM"

# Define the output file path
$outputFile = "D:\VM_Directory_List_2.txt"

# Get all files and directories recursively
$items = Get-ChildItem -Path $directory -Recurse

# Write the full names of items to the output file
$items | Select-Object FullName | Out-File -FilePath $outputFile

# Output to console
Write-Host "Directory listing of $directory has been saved to $outputFile"
