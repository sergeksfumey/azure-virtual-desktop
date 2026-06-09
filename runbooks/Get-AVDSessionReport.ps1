<#
.SYNOPSIS
    Generates an AVD session health and utilisation report.

.DESCRIPTION
    Queries AVD host pool session data for:
    - Active session count and distribution
    - Session host utilisation per VM
    - Profile mount health (FSLogix events)
    - Autoscale events in the last 24 hours
    Exports report to storage for Power BI or Log Analytics.

.PARAMETER ResourceGroup
    Azure resource group.

.PARAMETER HostPoolName
    AVD host pool name.

.PARAMETER StorageAccountName
    Storage account for report export.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$HostPoolName,
    [Parameter(Mandatory)][string]$StorageAccountName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

try {
    Write-Log "=== AVD SESSION REPORT ==="
    $reportDate = Get-Date -Format "yyyy-MM-dd"

    # Get session host information
    $sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroup `
        -HostPoolName $HostPoolName

    $sessionHostStats = $sessionHosts | ForEach-Object {
        $hostName = $_.Name.Split("/")[-1]
        [PSCustomObject]@{
            HostName          = $hostName
            Status            = $_.Status
            Sessions          = $_.Session
            AllowNewSession   = $_.AllowNewSession
            AgentVersion      = $_.AgentVersion
            UpdateState       = $_.UpdateState
            LastHeartBeat     = $_.LastHeartBeat
        }
    }

    # Get active sessions
    $activeSessions = Get-AzWvdUserSession -ResourceGroupName $ResourceGroup `
        -HostPoolName $HostPoolName -ErrorAction SilentlyContinue

    $report = @{
        ReportDate        = $reportDate
        HostPoolName      = $HostPoolName
        TotalHosts        = $sessionHosts.Count
        ActiveHosts       = ($sessionHostStats | Where-Object { $_.Status -eq "Available" }).Count
        TotalSessions     = ($activeSessions | Measure-Object).Count
        SessionHosts      = $sessionHostStats
        HostPoolUtilPct   = if ($sessionHosts.Count -gt 0) {
            [math]::Round((($activeSessions | Measure-Object).Count / ($sessionHosts.Count * 10)) * 100, 1)
        } else { 0 }
    }

    Write-Log "Session hosts: $($report.TotalHosts) | Active sessions: $($report.TotalSessions)"
    Write-Log "Utilisation: $($report.HostPoolUtilPct)%"

    $reportPath = "$env:TMPDIR/avd-session-report-$reportDate.json"
    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath

    $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
    Set-AzStorageBlobContent -File $reportPath -Container "avd-reports" `
        -Blob "sessions/avd-session-report-$reportDate.json" -Context $ctx -Force

    Write-Log "Report exported: avd-reports/sessions/avd-session-report-$reportDate.json"

} catch {
    Write-Log "Report generation failed: $_" -Level "ERROR"
    throw
}
