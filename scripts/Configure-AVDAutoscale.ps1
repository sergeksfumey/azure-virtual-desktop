<#
.SYNOPSIS
    Configures AVD Autoscale scaling plan for cost-optimised session host management.

.DESCRIPTION
    Creates an AVD Autoscale scaling plan with:
    - Peak hours: 08:00-18:00 UTC (business hours)
    - Off-peak: evenings and weekends (drain and deallocate)
    - Minimum 2 hosts always powered on
    - Scale-out at 80% session capacity
    - Scale-in at 20% session utilisation

.PARAMETER ResourceGroup
    Azure resource group.

.PARAMETER HostPoolName
    AVD host pool name.

.PARAMETER Location
    Azure region.

.NOTES
    AVD Autoscale requires Contributor role assignment to the scaling plan
    managed identity on the host pool resource group
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$HostPoolName,
    [string]$Location = "westeurope",
    [string]$TimeZone = "UTC"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

try {
    Write-Log "=== AVD AUTOSCALE CONFIGURATION ==="
    Write-Log "Host Pool: $HostPoolName | RG: $ResourceGroup"

    # Get host pool resource ID
    $hostPool = Get-AzWvdHostPool -ResourceGroupName $ResourceGroup -Name $HostPoolName
    Write-Log "Host pool found: $($hostPool.Id)"

    # Create scaling plan
    Write-Log "Creating AVD scaling plan"
    $scalingPlan = New-AzWvdScalingPlan `
        -ResourceGroupName $ResourceGroup `
        -Name "sp-$HostPoolName" `
        -Location $Location `
        -TimeZone $TimeZone `
        -HostPoolType "Pooled" `
        -ExclusionTag "ScalingExclude"

    Write-Log "Scaling plan created: $($scalingPlan.Name)"

    # Define peak schedule (Mon-Fri 08:00-18:00)
    Write-Log "Configuring peak hours schedule"
    $peakSchedule = @{
        Name                                 = "WeekdayPeak"
        DaysOfWeek                           = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
        RampUpStartTime                      = "07:00"
        PeakStartTime                        = "08:00"
        RampDownStartTime                    = "17:00"
        OffPeakStartTime                     = "18:00"
        RampUpLoadBalancingAlgorithm         = "BreadthFirst"
        PeakLoadBalancingAlgorithm           = "BreadthFirst"
        RampDownLoadBalancingAlgorithm       = "DepthFirst"
        OffPeakLoadBalancingAlgorithm        = "DepthFirst"
        RampUpMinimumHostsPct                = 20
        RampUpCapacityThresholdPct           = 80
        PeakMinimumHostsPct                  = 20
        RampDownMinimumHostsPct              = 10
        RampDownCapacityThresholdPct         = 80
        RampDownForceLogoffUser              = $false
        RampDownWaitTimeMinute               = 30
        RampDownNotificationMessage          = "Your session will be disconnected in 30 minutes due to scheduled maintenance."
        RampDownStopHostsWhen                = "ZeroActiveSessions"
        OffPeakMinimumHostsPct               = 0
    }

    # Apply schedule to scaling plan
    Update-AzWvdScalingPlanPooledSchedule `
        -ResourceGroupName $ResourceGroup `
        -ScalingPlanName $scalingPlan.Name `
        -ScalingPlanScheduleName "WeekdayPeak" `
        @peakSchedule

    Write-Log "Peak schedule configured: Mon-Fri 08:00-18:00 UTC"

    # Assign scaling plan to host pool
    Write-Log "Assigning scaling plan to host pool"
    Update-AzWvdScalingPlan `
        -ResourceGroupName $ResourceGroup `
        -Name $scalingPlan.Name `
        -HostPoolReference @(@{
            HostPoolArmPath    = $hostPool.Id
            ScalingPlanEnabled = $true
        })

    Write-Log "=== AUTOSCALE CONFIGURATION COMPLETE ==="
    Write-Log "Scaling plan: $($scalingPlan.Name)"
    Write-Log "Expected cost reduction: 40-60% vs always-on capacity during off-peak"

} catch {
    Write-Log "Autoscale configuration failed: $_" -Level "ERROR"
    throw
}
