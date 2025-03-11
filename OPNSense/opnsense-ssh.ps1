# Custom SSH launcher for OPNsense
param(
    [Parameter(Mandatory=$true)]
    [string]$Host,
    
    [Parameter(Mandatory=$false)]
    [string]$Command = ""
)

# Build SSH command
$sshArgs = @("-o", "SetEnv=SHELL=/bin/sh")

if ($Command -ne "") {
    # Replace 'bash' with 'sh' if found in the command
    if ($Command -match "bash") {
        $Command = $Command -replace "bash", "/bin/sh"
    }
    $sshArgs += @("-t", $Host, $Command)
} else {
    $sshArgs += @($Host)
}

# Execute SSH with proper arguments
& ssh $sshArgs
