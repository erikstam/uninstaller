# Intro
Installing apps is easy, just run a package. But what about removing/uninstalling the app?
Not every developer creates an uninstaller script or removal tool so who are you gonna call when you want to uninstall some software? Erik!!

Unfortunately you cannot upload Erik to your favorite MDM so he created this script instead.

## What does uninstaller do?
uninstaller.sh removes software including preferences, license info, cache files, etc. It will not remove user data.


## Why do you want to uninstall software?
This can be usefull during troubleshooting unstable software: First completely uninstall the software before a reinstallation.
Also if you want to automate a removal of software, for example after the migration to a different application.
In some cases a software upgrade will fail if an older version is not fully uninstalled.


## How does uninstaller work?
Run the uninstaller.sh script with the softwarename as the only required argument. For example
```
uninstaller.sh firefox
```

## How can i add my own titles to the script?
(work in progress)


| Label  | Description | Example |
| ------------- | ------------- |-------------|
| appTitle  | Software Title  |  appTitle="Jamf Connect"|
| appProcesses  | Process to kill during uninstall  |  appProcesses+=("Jamf Connect")|
| appFiles  | files/folders to be removed  |  appFiles+=("/Users/$loggedInUser/Library/Application Support/JamfConnect")|
| appLaunchAgents  | path to launchagent plist  |  appFiles+=("/Users/$loggedInUser/Library/Application Support/JamfConnect")|
| appLaunchDaemons  | path to launchdaemon plist  |  appFiles+=("/Users/$loggedInUser/Library/Application Support/JamfConnect")|
| appReceipts  | receipt to forget  |  appReceipts+=("com.teamviewer.AuthorizationPlugin")|
| preflightCommand (EXPERIMENTAL) | command to run BEFORE uninstalling |  preflightCommand+=("/usr/local/bin/authchanger -reset")|
| postflightCommand (EXPERIMENTAL) | command to run AFTER uninstalling |  postflightCommand+=("touch /tmp/.uninstall-done")|

