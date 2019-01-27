# MDT-Auto-Deployment

Microsoft Deployment Toolkit Auto-Deployment PowerShell Script v3.3

**Warning: This script is intended to run on a clean Windows installation which doesn’t have MDT/ADK installed/configured already. Unexpected results will arise when running on already configured deployment servers.**

Tested on Windows 10 1607, Server 2016 & 2019

## How to use
1) Download: https://github.com/pwshMgr/MDT-Auto-Deployment/archive/3.3.zip
2) Add your desired WIM files that you wish to auto import in the same folder where the script resides
3) Run with the below command:

```powershell
powershell -ExecutionPolicy Bypass -File mdt8456auto.ps1 -IncludeApplications -InstallWDS
```
You will be asked to enter the following information:
- ServiceAccountPassword – This is the password for the local service account that gets created when the script runs
- DeploymentShareDrive – This is to select which drive you want the deployment share to exist on, i.e. c:\

## Tasks the script completes
1) Download & install MDT (8456) & ADK (1809)
2) Creates a local user with the account name “svc_mdt” (for Read-Only DeploymentShare access)
3) Creates a new Deployment Share
4) Imports all WIM files placed in the script folder
5) Creates a standard client task sequence for each WIM image found
6) Edits bootstrap.ini with the Deployment Share access information
7) Disables x86 support (saves time when regenerating boot images)
8) Creates Boot media
9) OPTIONAL - Installs and configures WDS and imports boot file (include -InstallWDS switch)
10) OPTIONAL – Imports the following 64bit applications into MDT (include -IncludeApplications switch):
- Google Chrome Enterprise
- Mozilla Firefox
- 7-Zip
- Visual Studio Code
- Node.js
- MongoDB Community
- VLC Media Player
- Treesize Free
- Putty
- Office 365 monthly build
