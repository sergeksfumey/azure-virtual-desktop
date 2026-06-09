<#
.SYNOPSIS
    Compacts FSLogix profile containers to reclaim wasted space.

.DESCRIPTION
    FSLogix VHDX containers grow dynamically but do NOT auto-shrink when
    files are deleted. Without compaction, containers accumulate wasted space
    continuously -- driving unnecessary Azure Files Premium storage costs.

    This script identifies and compacts profile containers that have grown
    beyond a defined fragmentation threshold.

    Run as a weekly scheduled task during off-peak hours.

.PARAMETER ProfileSharePath
    Local or UNC path to FSLogix profile share.

.PARAMETER FragmentationThreshold
    Minimum fragmentation percentage before compaction. Default: 20%.

.PARAMETER MaxContainerSizeMB
    Alert if container exceeds this size (MB). Default: 30720 (30 GB).

.NOTES
    Run during off-peak hours when users are not logged in
    Compaction requires the container not be in use (no active sessions)
    Uses Microsoft's FRX.exe tool included with FSLogix installation
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$ProfileSharePath,
    [int]$FragmentationThreshold = 20,
    [int]$MaxContainerSizeMB = 30720
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

try {
    Write-Log "=== FSLOGIX PROFILE COMPACTION ==="
    Write-Log "Share: $ProfileSharePath | Threshold: $FragmentationThreshold%"

    $frxPath = "C:\Program Files\FSLogix\Appsrx.exe"
    if (-not (Test-Path $frxPath)) {
        throw "FRX.exe not found at $frxPath -- ensure FSLogix is installed"
    }

    $containers = Get-ChildItem -Path $ProfileSharePath -Filter "*.vhdx" -Recurse
    Write-Log "Found $($containers.Count) profile containers"

    $compacted = 0
    $skipped   = 0
    $errors    = 0

    foreach ($container in $containers) {
        $sizeMB = [math]::Round($container.Length / 1MB, 1)

        try {
            # Check if container is in use (locked)
            $stream = [System.IO.File]::Open($container.FullName, 'Open', 'Read', 'None')
            $stream.Close()

            # Container not in use -- compact it
            Write-Log "Compacting: $($container.Name) ($sizeMB MB)"
            $result = & $frxPath compact-vhd -filename $container.FullName 2>&1

            if ($LASTEXITCODE -eq 0) {
                $newSizeMB = [math]::Round((Get-Item $container.FullName).Length / 1MB, 1)
                $savedMB   = [math]::Round($sizeMB - $newSizeMB, 1)
                Write-Log "  Compacted: $sizeMB MB --> $newSizeMB MB (saved $savedMB MB)"
                $compacted++
            } else {
                Write-Log "  Compaction failed: $result" -Level "WARNING"
                $errors++
            }

            # Alert on oversized containers
            if ($newSizeMB -gt $MaxContainerSizeMB) {
                Write-Log "  ALERT: Container exceeds max size: $newSizeMB MB > $MaxContainerSizeMB MB" -Level "WARNING"
            }

        } catch [System.IO.IOException] {
            Write-Log "  Skipped (in use): $($container.Name)" -Level "WARNING"
            $skipped++
        } catch {
            Write-Log "  Error: $($container.Name): $_" -Level "ERROR"
            $errors++
        }
    }

    Write-Log "=== COMPACTION COMPLETE ==="
    Write-Log "Compacted: $compacted | Skipped (in use): $skipped | Errors: $errors"

} catch {
    Write-Log "Profile compaction failed: $_" -Level "ERROR"
    throw
}
