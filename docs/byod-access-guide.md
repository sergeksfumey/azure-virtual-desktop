# BYOD Access Guide

## BYOD Session Restrictions

When a personal (unmanaged) device accesses AVD:

What works:
- Full Windows 11 desktop within the browser session
- All cloud applications (Microsoft 365, web apps)
- Printing to cloud printers (direct from AVD session)
- Network drives mapped within the AVD session

What is restricted (data exfiltration prevention):
- Clipboard: copy-paste between local device and AVD session disabled
- Local drive mapping: personal drives not accessible within AVD session
- Local printing: personal printers not available in AVD session
- USB redirection: USB devices on personal device not accessible in AVD

Why these restrictions exist:
These controls prevent data from leaving the secure AVD session onto
an unmanaged personal device where corporate data protection policies
do not apply.

## BYOD Workarounds That Violate Policy

The following workarounds defeat the intent of BYOD session controls
and are policy violations:
- Photographing screen content with personal phone
- Using personal email or personal cloud storage to transfer files out
- Screenshotting sensitive data on personal device

Users should use OneDrive for Business or SharePoint for file access
rather than local drive mapping -- this works in BYOD sessions and
maintains data governance.

## User Communication Template

When communicating BYOD restrictions to end users:

"When accessing your work desktop from a personal device, some features
are limited to protect company data:
- You cannot copy text or files between your personal device and the
  work desktop session
- Your personal drives and printers are not available in the session
- These restrictions protect both you and the company -- they ensure
  work data stays within protected systems

To access files, use OneDrive for Business within your session.
To print, use cloud-connected printers accessible from within the session.

For questions or exceptions, contact IT helpdesk."
