# Graceful VM Memory Adjustment Script
# This version safely shuts down VMs before adjusting memory

param(
    [string]$VMName,
    [decimal]$NewMemoryGB,
    [decimal]$NewMinMemoryGB = $NewMemoryGB,
    [int]$TimeoutSeconds = 300  # 5 minute timeout for graceful shutdown
)

Write-Host "========================================="
Write-Host "   GRACEFUL VM MEMORY ADJUSTMENT"
Write-Host "========================================="
Write-Host ""

# Validate VM exists
$VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if (-not $VM) {
    Write-Host "ERROR: VM '$VMName' not found!" -ForegroundColor Red
    return
}

Write-Host "VM: $VMName"
Write-Host "Current Memory: $([math]::Round($VM.MemoryStartup/1GB, 2)) GB"
Write-Host "Target Memory: $NewMemoryGB GB"
Write-Host ""

# Check if VM has integration services
$IntegrationServices = Get-VMIntegrationService -VMName $VMName | Where-Object {$_.Name -eq "Shutdown"}
if ($IntegrationServices.Enabled -eq $false) {
    Write-Host "WARNING: Shutdown integration service not enabled!" -ForegroundColor Yellow
    Write-Host "The VM may not respond to graceful shutdown requests." -ForegroundColor Yellow
    
    $response = Read-Host "Continue with forced shutdown? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Operation cancelled."
        return
    }
}

# Attempt graceful shutdown
Write-Host "Initiating graceful shutdown..."
Stop-VM -Name $VMName -ErrorAction SilentlyContinue

# Wait for shutdown with timeout
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
while ($VM.State -ne 'Off' -and $stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
    $VM = Get-VM -Name $VMName
}
$stopwatch.Stop()

Write-Host ""

if ($VM.State -eq 'Off') {
    Write-Host "VM shut down gracefully in $([math]::Round($stopwatch.Elapsed.TotalSeconds)) seconds" -ForegroundColor Green
} else {
    Write-Host "WARNING: Graceful shutdown timed out after $TimeoutSeconds seconds!" -ForegroundColor Yellow
    $response = Read-Host "Force shutdown? (y/n)"
    if ($response -eq 'y') {
        Stop-VM -Name $VMName -Force
        Write-Host "VM forcefully stopped." -ForegroundColor Yellow
    } else {
        Write-Host "Operation cancelled. VM still running."
        return
    }
}

# Adjust memory
Write-Host ""
Write-Host "Adjusting memory configuration..."
try {
    Set-VMMemory -VMName $VMName -StartupBytes ([int64]$NewMemoryGB * 1GB) -MinimumBytes ([int64]$NewMinMemoryGB * 1GB)
    Write-Host "Memory adjusted successfully" -ForegroundColor Green
} catch {
    Write-Host "ERROR adjusting memory: $_" -ForegroundColor Red
    return
}

# Start VM
Write-Host "Starting VM..."
Start-VM -Name $VMName
Write-Host "VM started successfully" -ForegroundColor Green

# Wait and verify
Write-Host ""
Write-Host "Waiting for VM to fully start..."
Start-Sleep -Seconds 20

$VM = Get-VM -Name $VMName
Write-Host ""
Write-Host "Final Status:"
Write-Host "============="
Write-Host "State: $($VM.State)"
Write-Host "Memory Assigned: $([math]::Round($VM.MemoryAssigned/1GB, 2)) GB"
Write-Host "Memory Demand: $([math]::Round($VM.MemoryDemand/1GB, 2)) GB"
Write-Host "Memory Status: $($VM.MemoryStatus)"