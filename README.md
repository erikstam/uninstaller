# Intro
Installing apps is easy, just run a package. But what about removing/uninstalling the app?
Not every developer creates an uninstaller script or removal tool so the idea for uninstaller was born.

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
Just like Installomator (https://github.com/Installomator/Installomator) you can add your own labels for software you want to uninstall. Add your softwaretitle as separate file to the labels folder and run the assemble.sh script to generate a new uninstaller script to the build folder.
 Many thanks to the installomator-team for the separate labels mechanism and assemble script.
 
You can use these variables in your own label script.


| Key  | Description | Remarks | Example |
| ------------- | ------------- |-------------|-------------|
| appTitle  | Software Title  |  | appTitle="Jamf Connect"|
| appProcesses  | Process to kill during uninstall  | appTitle is used if appProcesses is left empty | appProcesses+=("Jamf Connect")|
| appFiles  | files/folders to be removed. | First entry MUST contain the full path to the application. Addition lines can contain path to plist file, app support folders or other data that must be installed |  appFiles+=("/Users/$loggedInUser/Library/Application Support/JamfConnect")|
| appLaunchAgents  | path to launchagent plist. | plist will be unloaded and removed |  appFiles+=("/Users/$loggedInUser/Library/Application Support/JamfConnect")|
| appLaunchDaemons  | path to launchdaemon plist. | plist will be unloaded and removed  |  appFiles+=("/Users/$loggedInUser/Library/Application Support/JamfConnect")|
| appReceipts  | receipt to forget  | BundleIdentifier from Info.plist is used if left empty  | appReceipts+=("com.teamviewer.AuthorizationPlugin")|
| preflightCommand | command to run BEFORE uninstalling |  | preflightCommand+=("/usr/local/bin/authchanger -reset")|
| postflightCommand | command to run AFTER uninstalling |  | postflightCommand+=("touch /tmp/.uninstall-done")|


There are 2 substitutions you can use in the label:

```
$loggedInUser
```

This will be replaced by the username of only the current logged in user:

For example: ```appFiles+=("/Users/$loggedInUser/Library/Application Support/JamfConnect")```

```
<<Users>>
```
This will be replaced by the path of EVERY user homefolder:

For example: ```appFiles+=("<<Users>>/Library/Application Support/JamfConnect")```

Because sometimes you want the remove files for every user on the Mac


## Example label
```
jamfconnect)
      appTitle="Jamf Connect"
      appProcesses+=("Jamf Connect")
      appFiles+=("/Applications/Jamf Connect.app")
      appFiles+=("/Library/Application Support/JamfConnect")
      appFiles+=("/usr/local/bin/authchanger")
      appFiles+=("/usr/local/lib/pam/pam_saml.so.2")
      appFiles+=("/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle")
      appFiles+=("/Library/Application Support/JamfConnect")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.connect.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.connect.unlock.login.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.jamf.connect.daemon.plist")
      preflightCommand+=("/usr/local/bin/authchanger -reset")
      ;;
```


## Further info
On the 19th of june 2023, Erik Stam and Sander Schram presented about this uninstaller script during the Dutch Macadmin meeting. The PDF of the presentation is included in this repo.

https://github.com/erikstam/uninstaller/blob/main/Uninstaller%20Presentation.pdf


## Can i help by adding new software labels?
YES! We encourage everyone to contribute to this project. You can add new labels in a github fork and create a pull request. Or you create an issue and put your code in there so we can add it later. Do not edit the main script (uninstaller.sh) because this is generates by the assemble.sh script.
