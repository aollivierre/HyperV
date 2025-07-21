# Get host memory information
$OS = Get-CimInstance Win32_OperatingSystem
$PhysicalMemory = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum

Write-Host "Host Memory Information:"
Write-Host "========================"
Write-Host "Total Physical RAM: $([math]::Round($PhysicalMemory.Sum/1GB,2)) GB"
Write-Host "Total Visible Memory: $([math]::Round($OS.TotalVisibleMemorySize/1MB,2)) GB"
Write-Host "Free Physical Memory: $([math]::Round($OS.FreePhysicalMemory/1MB,2)) GB"
Write-Host "Used Physical Memory: $([math]::Round(($OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory)/1MB,2)) GB"
Write-Host "Memory Usage Percentage: $([math]::Round((($OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory)/$OS.TotalVisibleMemorySize)*100,2))%"
Write-Host ""

# Get memory consumption by VMs
$VMMemory = Get-VM | Where-Object {$_.State -eq 'Running'} | Measure-Object -Property MemoryAssigned -Sum
Write-Host "VM Memory Consumption:"
Write-Host "====================="
Write-Host "Total Memory Assigned to VMs: $([math]::Round($VMMemory.Sum/1GB,2)) GB"
Write-Host "Number of Running VMs: $($VMMemory.Count)"
Write-Host ""

# Calculate host-only memory usage
$HostOnlyMemory = ($OS.TotalVisibleMemorySize - $OS.FreePhysicalMemory)/1MB - $VMMemory.Sum/1GB
Write-Host "Memory Distribution:"
Write-Host "==================="
Write-Host "Host System (Windows + Hyper-V): $([math]::Round($HostOnlyMemory,2)) GB"
Write-Host "Virtual Machines: $([math]::Round($VMMemory.Sum/1GB,2)) GB"
Write-Host "Free Memory: $([math]::Round($OS.FreePhysicalMemory/1MB,2)) GB"