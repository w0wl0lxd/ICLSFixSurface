# Intune CAB File Installation Script
# This script downloads a .cab file from a specified URL and installs it on the device

# Define Log File
$LogFile = "$env:TEMP\CabInstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Function to write to log file
Function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    $TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$TimeStamp - $Message" | Out-File -FilePath $LogFile -Append
}

# Start logging
Write-Log "Starting CAB file installation script"

# Configuration - GitHub repository values
$CabFileUrl = "https://raw.githubusercontent.com/w0wl0lxd/ICLSFixSurface/main/latestICLS.cab"
$LocalCabPath = "$env:TEMP\latestICLS.cab"
$MaxRetries = 3
$RetryWaitSeconds = 10

try {
    # Create a web client with TLS 1.2 support
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $WebClient = New-Object System.Net.WebClient

    # Download the CAB file with retry logic
    $RetryCount = 0
    $DownloadSuccess = $false

    while (-not $DownloadSuccess -and $RetryCount -lt $MaxRetries) {
        try {
            Write-Log "Attempting to download CAB file (Attempt $($RetryCount + 1))"
            $WebClient.DownloadFile($CabFileUrl, $LocalCabPath)
            
            if (Test-Path $LocalCabPath) {
                $FileSize = (Get-Item $LocalCabPath).Length
                if ($FileSize -gt 0) {
                    Write-Log "CAB file downloaded successfully ($FileSize bytes)"
                    $DownloadSuccess = $true
                }
                else {
                    Write-Log "Downloaded file has 0 bytes, will retry"
                    Remove-Item $LocalCabPath -Force -ErrorAction SilentlyContinue
                    $RetryCount++
                    Start-Sleep -Seconds $RetryWaitSeconds
                }
            }
        }
        catch {
            Write-Log "Error downloading CAB file: $_"
            $RetryCount++
            Start-Sleep -Seconds $RetryWaitSeconds
        }
    }

    # Verify download was successful
    if (-not $DownloadSuccess) {
        Write-Log "Failed to download CAB file after $MaxRetries attempts"
        throw "Failed to download CAB file after $MaxRetries attempts"
    }

    # Install the CAB file using DISM
    Write-Log "Installing CAB file using DISM"
    $DismResult = Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Add-Package /PackagePath:`"$LocalCabPath`" /NoRestart" -Wait -PassThru -RedirectStandardOutput "$env:TEMP\dism_output.txt" -RedirectStandardError "$env:TEMP\dism_error.txt"
    
    $DismOutput = Get-Content "$env:TEMP\dism_output.txt" -ErrorAction SilentlyContinue
    $DismError = Get-Content "$env:TEMP\dism_error.txt" -ErrorAction SilentlyContinue
    
    Write-Log "DISM Exit Code: $($DismResult.ExitCode)"
    Write-Log "DISM Output: $($DismOutput -join "`n")"
    
    if ($DismError) {
        Write-Log "DISM Errors: $($DismError -join "`n")"
    }

    # Check the result
    if ($DismResult.ExitCode -eq 0) {
        Write-Log "CAB file installed successfully"
    }
    elseif ($DismResult.ExitCode -eq 3010) {
        Write-Log "CAB file installed successfully, but a restart is required"
    }
    else {
        Write-Log "Failed to install CAB file, DISM exit code: $($DismResult.ExitCode)"
        throw "Failed to install CAB file, DISM exit code: $($DismResult.ExitCode)"
    }

    # Clean up
    if (Test-Path $LocalCabPath) {
        Remove-Item $LocalCabPath -Force
        Write-Log "Removed temporary CAB file"
    }

    Write-Log "Script completed successfully"
    exit 0
}
catch {
    Write-Log "Error: $_"
    Write-Log "Script failed"
    exit 1
}
