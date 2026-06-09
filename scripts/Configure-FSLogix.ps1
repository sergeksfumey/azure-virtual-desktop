<#
.SYNOPSIS
    Configures FSLogix profile containers on AVD session hosts.

.DESCRIPTION
    Applies FSLogix registry settings for profile container configuration:
    - Profile Container enabled with Azure Files share path
    - Office Container configured separately
    - Concurrent session handling enabled
    - Cloud Cache enabled for Azure Files resilience
    - Container size limits and cleanup policies

.PARAMETER ProfileSharePath
    UNC path to Azure Files Premium profile share.
    Format: \\storageaccount.file.core.windows.net\profileshare

.PARAMETER MaxProfileSize
    Maximum profile container size in MB. Default: 30720 (30 GB).

.NOTES
    Run via Intune device configuration policy or post-provisioning script
    Applied to all AVD session host VMs in the host pool
    Azure Files must be configured with identity-based access (AADKERB or AD DS)
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$ProfileSharePath,
    [int]$MaxProfileSize = 30720,
    [switch]$EnableOfficeContainer,
    [string]$OfficeSharePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWORD")
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

try {
    Write-Log "=== FSLOGIX CONFIGURATION ==="
    Write-Log "Profile share: $ProfileSharePath"

    $fslogixBase    = "HKLM:\SOFTWARE\FSLogix"
    $profilesBase   = "$fslogixBase\Profiles"
    $appsBase       = "$fslogixBase\Apps"

    # Profile Container
    Write-Log "Configuring FSLogix Profile Container"
    Set-RegistryValue -Path $profilesBase -Name "Enabled"              -Value 1
    Set-RegistryValue -Path $profilesBase -Name "VHDLocations"         -Value $ProfileSharePath -Type "String"
    Set-RegistryValue -Path $profilesBase -Name "VolumeType"           -Value "VHDX" -Type "String"
    Set-RegistryValue -Path $profilesBase -Name "IsDynamic"            -Value 1
    Set-RegistryValue -Path $profilesBase -Name "SizeInMBs"            -Value $MaxProfileSize
    Set-RegistryValue -Path $profilesBase -Name "FlipFlopProfileDirectoryName" -Value 1
    Set-RegistryValue -Path $profilesBase -Name "ConcurrentUserSessions" -Value 1
    Set-RegistryValue -Path $profilesBase -Name "DeleteLocalProfileWhenVHDShouldApply" -Value 1
    Set-RegistryValue -Path $profilesBase -Name "PreventLoginWithFailure" -Value 1
    Set-RegistryValue -Path $profilesBase -Name "PreventLoginWithTempProfile" -Value 1

    # Cloud Cache
    Write-Log "Configuring Cloud Cache"
    Set-RegistryValue -Path "$profilesBase\CloudCache" -Name "Enabled" -Value 1
    Set-RegistryValue -Path "$profilesBase\CloudCache" -Name "ClearCacheOnLogoff" -Value 0

    # Profile exclusions (prevent common bloat from being stored in container)
    Write-Log "Configuring profile exclusions"
    $exclusions = @(
        "%temp%\*",
        "%localappdata%\Temp\*",
        "%localappdata%\Microsoft\Windows\INetCache\*",
        "%localappdata%\Microsoft\Windows\WebCache\*"
    )
    Set-RegistryValue -Path "$profilesBase\Exclusions" -Name "ExclusionList" `
        -Value ($exclusions -join "|") -Type "String"

    # Office Container (separate VHDX for Office data)
    if ($EnableOfficeContainer -and $OfficeSharePath) {
        Write-Log "Configuring Office Container"
        Set-RegistryValue -Path "$appsBase\OfficeContainer" -Name "Enabled" -Value 1
        Set-RegistryValue -Path "$appsBase\OfficeContainer" -Name "VHDLocations" `
            -Value $OfficeSharePath -Type "String"
        Set-RegistryValue -Path "$appsBase\OfficeContainer" -Name "VolumeType" `
            -Value "VHDX" -Type "String"
        Set-RegistryValue -Path "$appsBase\OfficeContainer" -Name "IsDynamic" -Value 1
        Set-RegistryValue -Path "$appsBase\OfficeContainer" -Name "SizeInMBs" -Value 20480
        Write-Log "Office Container configured: $OfficeSharePath"
    }

    Write-Log "=== FSLOGIX CONFIGURATION COMPLETE ==="
    Write-Log "Profile share: $ProfileSharePath"
    Write-Log "Max profile size: $MaxProfileSize MB"
    Write-Log "Cloud Cache: enabled"
    Write-Log "Restart session host for FSLogix changes to take effect"

} catch {
    Write-Log "FSLogix configuration failed: $_" -Level "ERROR"
    throw
}
