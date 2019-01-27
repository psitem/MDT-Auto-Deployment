# Microsoft Deployment Toolkit 8450 Automatic Setup
# Author: Sam Tucker (https://github.com/pwshMgr)
# Version: 3.3
# Release date: 27/01/2019
# Tested on Windows 10 1607, Windows Server 2016 & 2019

#Requires -RunAsAdministrator

#Input Parameters
param (
    [Parameter(Mandatory = $true)]
    [string] $ServiceAccountPassword,

    [Parameter(Mandatory = $true)]
    [ValidateScript( {Test-Path $_})]
    [string]$DeploymentShareDrive,

    [Parameter(Mandatory = $false)]
    [switch] $IncludeApplications,

    [Parameter(Mandatory = $false)]
    [switch] $InstallWDS
)

$ErrorActionPreference = "Stop"
$DeploymentShareDrive = $DeploymentShareDrive.TrimEnd("\")

Write-Output "Downloading MDT 8456"
$params = @{
    Source      = "https://download.microsoft.com/download"+
    "/3/3/9/339BE62D-B4B8-4956-B58D-73C4685FC492/MicrosoftDeploymentToolkit_x64.msi"
    Destination = "$PSScriptRoot\MicrosoftDeploymentToolkit_x64.msi"
}
Start-BitsTransfer @params

Write-Output "Downloading ADK 1809"
$params = @{
    Source      = "http://download.microsoft.com/download"+
    "/0/1/C/01CC78AA-B53B-4884-B7EA-74F2878AA79F/adk/adksetup.exe"
    Destination = "$PSScriptRoot\adksetup.exe"
}
Start-BitsTransfer @params

Write-Output "Downloading ADK 1809 WinPE Addon"
$params = @{
    Source      = "http://download.microsoft.com/download"+
    "/D/7/E/D7E22261-D0B3-4ED6-8151-5E002C7F823D/adkwinpeaddons/adkwinpesetup.exe"
    Destination = "$PSScriptRoot\adkwinpesetup.exe"
}
Start-BitsTransfer @params

#Run Installs
Write-Output "Installing MDT"
Start-Process msiexec.exe -Wait -ArgumentList "/i ""$PSScriptRoot\MicrosoftDeploymentToolkit_x64.msi"" /qn"

Write-Output "Installing ADK"
$params = @{
    FilePath     = "$PSScriptRoot\adksetup.exe"
    ArgumentList = "/quiet /features OptionId.DeploymentTools"
}
Start-Process @params -Wait

Write-Output "Installing ADK 1809 WinPE Addon"
$params = @{
    FilePath     = "$PSScriptRoot\adkwinpesetup.exe"
    ArgumentList = "/quiet /features OptionId.WindowsPreinstallationEnvironment"
}
Start-Process @params -Wait

#Import MDT Module
Write-Output "Importing MDT Module"
Import-Module "$env:SystemDrive\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

#Create Deployment Share
Write-Output "Create Deployment Share"
$localUser = "svc_mdt"
$localUserPasswordSecure = ConvertTo-SecureString $ServiceAccountPassword -AsPlainText -Force
New-LocalUser -AccountNeverExpires -Name "svc_mdt" -Password $localUserPasswordSecure -PasswordNeverExpires
New-Item -Path "$DeploymentShareDrive\DeploymentShare" -ItemType directory
New-SmbShare -Name "DeploymentShare$" -Path "$DeploymentShareDrive\DeploymentShare" -ReadAccess "$env:COMPUTERNAME\svc_mdt"

$params = @{
    Name        = "DS001"
    PSProvider  = "MDTProvider"
    Root        = "$DeploymentShareDrive\DeploymentShare"
    Description = "MDT Deployment Share"
    NetworkPath = "\\$env:COMPUTERNAME\DeploymentShare$"
}
New-PSDrive @params -Verbose | Add-MDTPersistentDrive -Verbose

#Import WIM
Write-Output "Checking for wim files"
$Wims = Get-ChildItem $PSScriptRoot -Filter "*.wim" | Select-Object -ExpandProperty FullName
if (!$Wims) {
    Write-Output "No wim files found"
}

if ($Wims) {
    foreach($Wim in $Wims){
    $WimName = Split-Path $Wim -Leaf
    $WimName = $WimName.TrimEnd(".wim")
    Write-Output "$WimName found - will import"
    $params = @{
        Path              = "DS001:\Operating Systems"
        SourceFile        = $Wim
        DestinationFolder = $WimName
    }
    $OSData = Import-MDTOperatingSystem @params -Verbose
    }
}

#Create Task Sequence for each Operating System
Write-Output "Creating Task Sequence for each imported Operating System"
$OperatingSystems = Get-ChildItem -Path "DS001:\Operating Systems"

if ($OperatingSystems) {
    [int]$counter = 0
    foreach ($OS in $OperatingSystems){
    $Counter++
    $WimName = Split-Path -Path $OS.Source -Leaf
    $params = @{
        Path                = "DS001:\Task Sequences"
        Name                = "$($OS.Description) in $WimName"
        Template            = "Client.xml"
        Comments            = ""
        ID                  = $Counter
        Version             = "1.0"
        OperatingSystemPath = "DS001:\Operating Systems\$($OS.Name)"
        FullName            = "fullname"
        OrgName             = "org"
        HomePage            = "about:blank"
        Verbose             = $true
    }
    Import-MDTTaskSequence @params
    }
}

if (!$wimPath) {
    Write-Output "Skipping as no WIM found"
}

#Edit Bootstrap.ini
$BootstrapIni = @"
[Settings]
Priority=Default
[Default]
DeployRoot=\\$env:COMPUTERNAME\DeploymentShare$
SkipBDDWelcome=YES
UserDomain=$env:COMPUTERNAME
UserID=svc_mdt
UserPassword=$ServiceAccountPassword
"@

Set-Content -Path "$DeploymentShareDrive\DeploymentShare\Control\Bootstrap.ini" -Value $BootstrapIni -Force -Confirm:$False

#Disable x86 Support
$DeploymentShareSettings = "$DeploymentShareDrive\DeploymentShare\Control\Settings.xml"
$xmlDoc = [XML](Get-Content $DeploymentShareSettings)
$xmldoc.Settings.SupportX86 = "False"
$xmlDoc.Save($DeploymentShareSettings)

#Create LiteTouch Boot WIM & ISO
Write-Output "Creating LiteTouch Boot Media"
Update-MDTDeploymentShare -Path "DS001:" -Force -Verbose

#Download & Import Office 365 2016
if ($IncludeApplications) {
    Write-Output "Downloading Office Deployment Toolkit"
    New-Item -ItemType Directory -Path "$PSScriptRoot\odt"
    $params = @{
        Source      = "https://download.microsoft.com/download"+
        "/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_11306-33602.exe"
        Destination = "$PSScriptRoot\odt\officedeploymenttool.exe"
    }
    Start-BitsTransfer @params

    Write-Output "Extracting Office Deployment Toolkit"
    $params = @{
        FilePath     = "$PSScriptRoot\odt\officedeploymenttool.exe"
        ArgumentList = "/quiet /extract:$PSScriptRoot\odt"
    }
    Start-Process @params -Wait
    Remove-Item "$PSScriptRoot\odt\officedeploymenttool.exe" -Force -Confirm:$false
    Write-Output "Remove Visio"
    $xml = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="Monthly">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
      <ExcludeApp ID="Groove" />
    </Product>
  </Add>
</Configuration>
"@
    Set-Content -Path "$PSScriptRoot\odt\configuration.xml" -Value $xml -Force -Confirm:$false

    Write-Output "Importing Office 365 into MDT"
    $params = @{
        Path                  = "DS001:\Applications"
        Name                  = "Microsoft Office 365 2016 Monthly"
        ShortName             = "Office 365 2016"
        Publisher             = "Microsoft"
        Language              = ""
        Enable                = "True"
        Version               = "Monthly"
        Verbose               = $true
        CommandLine           = "setup.exe /configure configuration.xml"
        WorkingDirectory      = ".\Applications\Microsoft Office 365 2016 Monthly"
        ApplicationSourcePath = "$PSScriptRoot\odt" 
        DestinationFolder     = "Microsoft Office 365 2016 Monthly"
    }
    Import-MDTApplication @params
}

if ($IncludeApplications) {
    $AppList = @"
[
    {
        "name": "Google Chrome Enterprise",
        "version": "70.0.3538.11000",
        "download": "https://dl.google.com/tag/s/dl/chrome/install/googlechromestandaloneenterprise64.msi",
        "filename": "googlechromestandaloneenterprise64.msi",
        "install": "msiexec /i googlechromestandaloneenterprise64.msi /qb"
    },
    {
        "name": "Mozilla Firefox",
        "version": "63.0.3",
        "download": "https://download-installer.cdn.mozilla.net/pub/firefox/releases/63.0.3/win64/en-GB/Firefox%20Setup%2063.0.3.exe",
        "filename": "firefox.exe",
        "install": "firefox.exe /S"
    },
    {
        "name": "7-Zip",
        "version": "18.05",
        "download": "https://www.7-zip.org/a/7z1805-x64.msi",
        "filename": "7z1805-x64.msi",
        "install": "msiexec /i 7z1805-x64.msi /qb"
    },
    {
        "name": "Visual Studio Code",
        "version": "1.29.1",
        "download": "https://az764295.vo.msecnd.net/stable/bc24f98b5f70467bc689abf41cc5550ca637088e/VSCodeUserSetup-x64-1.29.1.exe",
        "filename": "VSCodeUserSetup-x64-1.29.1.exe",
        "install": "VSCodeUserSetup-x64-1.29.1.exe /VERYSILENT"
    },
    {
        "name": "Node.js",
        "version": "10.13.0",
        "download": "https://nodejs.org/dist/v10.13.0/node-v10.13.0-x64.msi",
        "filename": "node-v10.13.0-x64.msi",
        "install": "msiexec /i node-v10.13.0-x64.msi /qb"
    },
    {
        "name": "MongoDB",
        "version": "4.0.3",
        "download": "https://fastdl.mongodb.org/win32/mongodb-win32-x86_64-2008plus-ssl-4.0.3-signed.msi",
        "filename": "mongodb-win32-x86_64-2008plus-ssl-4.0.3-signed.msi",
        "install": "msiexec /i mongodb-win32-x86_64-2008plus-ssl-4.0.3-signed.msi /qb"
    },
    {
        "name": "VLC media player",
        "version": "3.0.4",
        "download": "http://videolan.mirrors.nublue.co.uk/vlc/3.0.4/win64/vlc-3.0.4-win64.exe",
        "filename": "vlc-3.0.4-win64.exe",
        "install": "vlc-3.0.4-win64.exe /L=1033 /S"
    },
    {
        "name": "Treesize Free",
        "version": "4.22",
        "download": "https://www.jam-software.de/treesize_free/TreeSizeFreeSetup.exe",
        "filename": "TreeSizeFreeSetup.exe",
        "install": "TreeSizeFreeSetup.exe /VERYSILENT /NORESTART"
    },
    {
        "name": "Putty",
        "version": "0.70",
        "download": "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.70-installer.msi",
        "filename": "putty-64bit-0.70-installer.msi",
        "install": "msiexec /i putty-64bit-0.70-installer.msi /qb"
    }
]
"@
    $AppList = ConvertFrom-Json $AppList

    foreach ($Application in $AppList) {
        New-Item -Path "$PSScriptRoot\mdt_apps\$($application.name)" -ItemType Directory -Force
        Start-BitsTransfer -Source $Application.download -Destination "$PSScriptRoot\mdt_apps\$($application.name)\$($Application.filename)"
        $params = @{
            Path                  = "DS001:\Applications"
            Name                  = $Application.name
            ShortName             = $Application.name
            Publisher             = ""
            Language              = ""
            Enable                = "True"
            Version               = $Application.version
            Verbose               = $true
            CommandLine           = $Application.install
            WorkingDirectory      = ".\Applications\$($Application.name)"
            ApplicationSourcePath = "$PSScriptRoot\mdt_apps\$($application.name)"
            DestinationFolder     = $Application.name
        }
        Import-MDTApplication @params
    }
    Remove-Item -Path "$PSScriptRoot\mdt_apps" -Recurse -Force -Confirm:$false
}

#Install WDS
If ($InstallWDS) {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    if ($OSInfo.ProductType -eq 1) {
        Write-Output "Workstation OS - WDS Not available"
    }
    else {
        Write-Output "Server OS - Checking if WDS available on this version"
        $WDSCheck = Get-WindowsFeature -Name WDS
        if ($WDSCheck) {
            Write-Output "WDS Role Available - Installing"
            Add-WindowsFeature -Name WDS -IncludeAllSubFeature -IncludeManagementTools
            $WDSUtilResults = wdsutil /initialize-server /remInst:"$DeploymentShareDrive\remInstall" /standalone
            $WDSConfigResults = wdsutil /Set-Server /AnswerClients:All
            Import-WdsBootImage -Path "$DeploymentShareDrive\DeploymentShare\Boot\LiteTouchPE_x64.wim" -NewImageName "MDT Litetouch" -SkipVerify
        }
        else {
            Write-Output "WDS Role not available on this version of Server"
        }
    }
}

#Finish
Write-Output "Script Finished"
Pause