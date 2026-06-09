# FSLogix Operations Guide

## Profile Container Troubleshooting

Common issues and resolution:

Profile fails to mount (EventID 25):
1. Check Azure Files share availability and connectivity
2. Verify NTFS permissions: user has Modify access to share
3. Check storage account firewall allows session host subnet
4. Verify AADKERB authentication is working: klist tickets
5. Check FSLogix log: C:\ProgramData\FSLogix\Logs\Profile

Slow logon times (> 10 seconds):
1. Check Azure Files Premium IOPS metrics -- throttling?
2. Review container size: large containers mount slower
3. Run compaction: Invoke-ProfileCompaction.ps1
4. Check Cloud Cache status -- is cache healthy?
5. Review profile exclusions -- are large temp files being captured?

Container locked after abnormal session termination:
1. Identify container: \\share\username_SID\Profile_username.vhdx
2. Verify no active sessions for the user
3. Disconnect stale VHD: Dismount-VHD -Path <container-path>
4. Or: use FSLogix Profile Debugger to forcibly unlock

## Profile Container Sizing Guidelines

Starting quota per user:
- Standard knowledge worker: 5-10 GB initial (dynamic, grows as needed)
- Office-heavy user: 10-20 GB (large OST, Teams cache)
- Power user / developer: 20-30 GB

Monitor with KQL:
- Alert if container > 25 GB (approaching 30 GB max)
- Alert if FSLogix failure rate > 2% in any 15-minute window
- Alert if profile mount time > 15 seconds (P95)

## Weekly Compaction Checklist

- [ ] Verify no users logged in to target host pool
- [ ] Run Invoke-ProfileCompaction.ps1 against profile share
- [ ] Review compaction results -- containers compacted, space saved
- [ ] Alert if > 10% of containers skipped (users in unexpected sessions)
- [ ] Alert if any container exceeds 30 GB after compaction
- [ ] Log results to Azure Storage for trend analysis
