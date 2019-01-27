# MDT-Auto-Deployment

Microsoft Deployment Toolkit Auto-Deployment PowerShell Script

**Warning: This script is intended to run on a clean Windows installation which doesn’t have MDT/ADK installed/configured already. Unexpected results will arise when running on already configured deployment servers.**

Tested on Windows 10 1607, Server 2016 & 2019

## How to use
1) Download and save the script in this repo
2) Add your desired WIM file that you wish to auto import in the same folder where the script resides
3) Run with the below command:

```powershell
powershell -ExecutionPolicy Bypass -File mdt8456auto.ps1 -IncludeApplications -InstallWDS
```
You will be asked to enter the following information:
- ServiceAccountPassword – This is the password for the local service account that gets created when the script runs
- DeploymentShareDrive – This is to select which drive you want the deployment share to exist on, i.e. c:\

## Tasks the script completes
1) Download MDT (8456) & ADK (1809)
2) Silently install MDT & ADK (with Deployment Tools & WindowsPE)
3) Creates a local user with the account name “svc_mdt” (for Read-Only DeploymentShare access)
4) Creates a new Deployment Share
5) Imports all WIM files placed in the script folder
6) Creates a standard client task sequence for each WIM image found
7) Edits bootstrap.ini with the Deployment Share access information
8) Disables x86 support (saves time when regenerating boot images)
9) Creates Boot media
10) OPTIONAL - Installs and configures WDS and imports boot file (include -InstallWDS switch)
11) OPTIONAL – Imports the following 64bit applications into MDT (include -IncludeApplications switch):
- Google Chrome Enterprise
- Mozilla Firefox
- 7-Zip
- Visual Studio Code
- Node.js
- MongoDB Community
- VLC Media Player
- Treesize Free
- Putty
- Office 365 2016 Monthly build without old OneDrive client
