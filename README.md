MCM / SCCM Deploy Automation Tool

📖 Project Description

The MCM / SCCM Deploy Automation Tool is a fully Open Source, Graphical User Interface (GUI) automation project written entirely in PowerShell. It is designed to simplify and automate the creation, distribution, and deployment of applications within Microsoft Configuration Manager (MCM/SCCM).

The system allows network administrators and IT professionals to set up "Folder Monitoring" on network shares. When a new installation file (such as an MSI) is dropped into the monitored folder, the system detects it and automatically:

Cleans up any previous versions of the application (if they exist).

Creates the new application in SCCM.

Distributes the content to designated Distribution Point (DP) groups.

Deploys it as a "Required" installation to a predefined Collection.

Sends email notifications upon success or failure.

🎯 The Problem It Solves

Managing software deployments in SCCM is often a lengthy, manual, and multi-step process. This project addresses several key IT challenges:

Airgapped & High-Security Network Support: In highly restricted or airgapped environments, every installation file must be rigorously inspected, scanned, and whitelisted before entering the secure network. Because external software catalogs and automated MCM synchronization features cannot function without internet access, packaging approved software often becomes a severe manual bottleneck. This tool bridges that gap perfectly: once an installation file clears all security gateways (like CDR, Sandbox detonation, or hash whitelisting) and is transferred to the secure zone, administrators can simply drop the approved MSI into the monitored folder. The tool instantly ingests it into SCCM, adhering to strict security workflows while completely bypassing the need for manual packaging.

Time Savings & Error Reduction: Eliminates manual clicks in the SCCM console. The entire process is handled behind the scenes consistently and securely.

Folder-Based Automation (Drop-and-Deploy): Enables a streamlined workflow where simply copying an MSI file to a specific folder triggers a background task that handles the entire SCCM setup process.

Accessibility for Helpdesk/Support: The unified GUI allows IT staff who are not SCCM experts or PowerShell developers to configure automated deployments effortlessly.

Centralized Management & Tracking: The system stores all configurations in organized JSON files, manages background Scheduled Tasks, and maintains robust logs.


✨ Key Features

Unified Graphical Interface: Manage global environment settings and application configurations through a clean Windows Forms GUI.

Automated Scheduled Task Creation: Adding an application automatically registers a Windows Scheduled Task (running with appropriate credentials) to monitor the target folder.

Anti-Duplication Lock: The watcher script includes a cooldown mechanism to prevent multiple triggers if a file is modified multiple times during copy.

Email Notifications: Built-in SMTP support to alert administrators when a deployment succeeds or fails.

Safe Lifecycle Management: Safely removes active deployments before deleting or updating an application, preventing orphaned SCCM objects.

📁 Folder Structure

MCM-Deploy-Automation/
│
├── SCCM-Manager.ps1         # The main GUI application for managing settings and tasks
├── Start-AppWatcher.ps1     # The watcher script that monitors folders and triggers actions
├── Create-SCCMApp.ps1       # The payload script handling SCCM creation and deployment
├── Remove-SCCMApp.ps1       # The payload script for safely cleaning up old apps/deployments
├── Env-Config.json          # (Auto-generated) Stores global SCCM environment settings
│
└── AppConfigs/              # (Auto-generated) Contains JSON configuration files for each monitored app
    ├── AppName1.json
    └── AppName2.json


⚙️ Core Scripts Explained

1. SCCM-Manager.ps1 (Unified Graphical Interface)

This is the main entry point for administrators. It provides a visual dashboard to configure Global Settings (like Site Code, Module Path, SMTP details) and manage Application configurations. When you add a new app via the GUI, it saves a JSON config in the AppConfigs folder and automatically registers a Windows Scheduled Task to run the watcher script at startup.

2. Start-AppWatcher.ps1 (The Folder Monitor)

This script is executed continuously in the background by the Scheduled Task. It uses a FileSystemWatcher to listen for new .msi files dropped into the target directory.

It includes an anti-duplication lock to ensure the deployment doesn't trigger multiple times while a large file is still copying.

Once the file is fully unlocked and ready, it triggers Remove-SCCMApp.ps1 (to clear out previous iterations) followed immediately by Create-SCCMApp.ps1.

3. Create-SCCMApp.ps1 (SCCM Creation & Deployment Payload)

This script performs the heavy lifting inside SCCM. Triggered by the watcher, it:

Connects to the SCCM Site drive.

Resolves the exact unique Collection ID to prevent naming conflicts.

Creates the Application and adds the MSI Deployment Type.

Distributes the content to the specified DP Group.

Creates a "Required" Deployment to the target Collection.

Sends a success or failure email report to the IT team.

4. Remove-SCCMApp.ps1 (Safe Cleanup Payload)

Deleting an application in SCCM directly will fail if there are active deployments. This script ensures a safe cleanup process:

It searches for all active deployments attached to the specified application and removes them.

Once the deployments are cleared, it permanently deletes the Application from SCCM, making way for the new version to be created by the Watcher.

📋 Prerequisites

Operating System: Windows Server or Windows 10/11 with administrative privileges.

PowerShell: Version 5.1 or later.

SCCM Console: The Configuration Manager Admin Console must be installed on the machine running the script (provides the ConfigurationManager.psd1 module).

Permissions:

The user running the GUI needs local Admin rights to create Scheduled Tasks.

The designated Scheduled Task user needs "Full Administrator" or equivalent Application Deployment rights in SCCM, plus read/write access to the monitored network shares.

🚀 How to Use

Launch the Tool: Run .\SCCM-Manager.ps1 as an Administrator.

Configure Environment: Click Global Settings and set your Site Code, Log Directory, and SMTP details.

Add an Application: Click Add Application, enter the application name, target folder, DP group, and target Collection ID. Supply the task password to register the background watcher.

Deploy: Simply drop an .msi file into the designated folder. The system will detect it and automate the rest!

Monitor: Check the log files in your configured Log Directory or wait for the SMTP email notification.

🤝 Open Source & Contributing

This is a community-driven, Open Source project aimed at helping sysadmins and IT professionals streamline their SCCM workflows.

Contributions, issues, and feature requests are highly encouraged and welcome!

Fork the repository.

Create a feature branch (git checkout -b feature/AmazingFeature).

Commit your changes (git commit -m 'Add some AmazingFeature').

Push to the branch (git push origin feature/AmazingFeature).

Open a Pull Request.

