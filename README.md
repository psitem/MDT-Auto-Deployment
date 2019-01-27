# MDT-Auto-Deployment

###Microsoft Deployment Toolkit Auto-Deployment PowerShell script

**Warning: This script is intended to run on a clean Windows installation which doesn’t have MDT/ADK installed/configured already. Unexpected results will arise when running on already configured deployment servers.**

## Run with PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File mdt8450auto.ps1 -IncludeApplications -InstallWDS
```

## Current Tasks
1) Download MDT (8456) & ADK (1809)
2) Silently install MDT & ADK (with Deployment Tools & WindowsPE)
3) Creates a local user with the account name “svc_mdt” (for Read-Only DeploymentShare access)
4) Creates a new Deployment Share
5) Imports all WIM files placed in the script folder
6) Creates a standard client task sequence for each WIM image found
7) Edits bootstrap.ini with the Deployment Share access information
8) Creates Boot media
9) OPTIONAL - Installs and configures WDS and imports boot file (include -InstallWDS switch)
10) OPTIONAL – Imports the following 64bit applications into MDT (include -IncludeApplications switch):
– Google Chrome Enterprise
– Mozilla Firefox
– 7-Zip
– Visual Studio Code
– Node.js
– MongoDB Community
– VLC Media Player
– Treesize Free
- Putty
- Office 365 2016 Monthly build without old OneDrive client