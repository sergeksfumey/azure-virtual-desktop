# Architecture Notes -- Azure Virtual Desktop for Hybrid Workforce

## Host Pool Configuration

Host pool: avd-hostpool
Type: Pooled (Breadth-First)
Max sessions per host: 10
OS: Windows 11 Enterprise Multi-Session + Microsoft 365 Apps
VM SKU: Standard_D4s_v5 (4 vCPU, 16 GB RAM) -- adjust per workload profile

Availability Zone distribution:
- Session host 1: Zone 1
- Session host 2: Zone 2
- Session host 3: Zone 3
- Additional hosts: distributed round-robin

Azure Compute Gallery image:
- Base: Windows 11 Enterprise Multi-Session 22H2
- Optimised: Microsoft 365 Apps, Teams, Edge
- Security baseline: CIS Level 1 applied
- Versioning: sig-avd-prod/img-win11-ms/1.0.0
- Promotion: dev --> staging --> prod with staged testing

## FSLogix Configuration

Registry path: HKLM:\SOFTWARE\FSLogix\Profiles

Key settings:
- Enabled: 1
- VHDLocations: \\<storage>.file.core.windows.net\profileshare
- VolumeType: VHDX (not VHD -- better performance and concurrent session support)
- IsDynamic: 1 (dynamic sizing -- container grows with content)
- SizeInMBs: 30720 (30 GB max -- review per user population)
- FlipFlopProfileDirectoryName: 1 (username_SID format for readability)
- ConcurrentUserSessions: 1 (required for multi-session AVD)
- CloudCache: enabled (local cache reducing Azure Files dependency)
- PreventLoginWithFailure: 1 (block login if profile fails to mount)
- PreventLoginWithTempProfile: 1 (block temporary profile fallback)

Profile exclusions (prevent bloat):
- %temp%\* (temporary files)
- %localappdata%\Temp\*
- %localappdata%\Microsoft\Windows\INetCache\* (IE/Edge cache)
- %localappdata%\Microsoft\Windows\WebCache\*

Office Container (separate VHDX):
- VHDLocations: same share, separate container file
- SizeInMBs: 20480 (20 GB)
- Isolates: Teams cache, OneNote cache, Outlook OST

## Compaction Schedule

Weekly compaction required to prevent container bloat.
Schedule: Sunday 02:00 UTC (minimum active sessions)

Trigger Invoke-ProfileCompaction.ps1 via:
- Azure Automation Runbook (recommended)
- Intune scheduled task
- Azure DevOps scheduled pipeline

Monitor: alert if compaction backlog > 20% of containers per week.

## Autoscale Configuration

Scaling plan: sp-avd-hostpool

Peak schedule (Mon-Fri 07:00-18:00 UTC):
- Ramp up: 07:00-08:00 (power on hosts proactively)
- Peak: 08:00-17:00 (maintain BreadthFirst, scale-out at 80% capacity)
- Ramp down: 17:00-18:00 (switch to DepthFirst, drain hosts)
- Off-peak: 18:00+ (deallocate idle hosts, minimum 0)

Off-peak (evenings + weekends):
- Minimum hosts: 0 (full deallocate off-peak for maximum savings)
- Exception: adjust minimum to 2 if business requires 24/7 availability

Force logoff configuration:
- Drain mode: prevents new sessions
- Wait time: 30 minutes before force logoff
- Notification: "Session disconnecting in 30 minutes"
- Adjust wait time based on user workflows

## Conditional Access Policy Configuration

Policy 1 (CA-AVD-001): Require MFA -- AVD Users
- Target app: Azure Virtual Desktop (app ID)
- Users: AVD-Users group
- Grant: Require MFA
- State: Enabled

Policy 2 (CA-AVD-002): Require Compliant Device -- Corporate
- Target app: Azure Virtual Desktop
- Users: AVD-Users group
- Filter: exclude unmanaged devices
- Grant: Require Intune compliant OR Hybrid AAD joined
- State: Enabled

Policy 3 (CA-AVD-003): BYOD Session Controls
- Target app: Azure Virtual Desktop
- Users: AVD-Users group
- Device filter: deviceManagementType -ne "compliant"
- Session: restrict clipboard, printing, drive redirection
- State: Enabled

Break-glass exclusion:
- GRP-BreakGlass group excluded from all CA policies
- Any break-glass sign-in triggers P1 Sentinel alert

## NSG Rules for Session Hosts

Required outbound (AVD control plane):
- TCP 443 to WindowsVirtualDesktop service tag
- TCP 443 to AzureMonitor service tag
- UDP 3478 + TCP 3478 to AzureFrontDoor (Teams media optimisation)

No inbound from internet required:
- Users connect via AVD gateway -- session hosts not directly reachable
- Management via Azure Bastion or Intune

## Azure Files Authentication

AADKERB (Azure AD Kerberos):
- Recommended for Azure AD joined session hosts
- No on-premises AD DS or AADDS required
- Kerberos tickets issued by Azure AD for user identity
- NTFS permissions set on share using Entra ID identities

Configuration:
1. Enable AADKERB on storage account:
   az storage account update --enable-files-aadkerb true
2. Set share-level permissions:
   - FSLogix service account: Storage File Data SMB Share Elevated Contributor
   - Users group: Storage File Data SMB Share Contributor
3. Set NTFS permissions via elevated session:
   icacls E:\Profiles /grant "CORP\Domain Users:(OI)(CI)(M)" /T
