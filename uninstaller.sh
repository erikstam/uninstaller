#!/bin/zsh --no-rcs

# uninstaller
# Removes software and related files
#
# https://github.com/erikstam/uninstaller

# set to 0 for production, 1 for debugging
# no actual uninstallation will be performed
DEBUG=0

# notify behavior
NOTIFY=success
# options:
#   - success      notify the user on success
#   - silent       no notifications
#   - all          all notifications (great for Self Service installation)

# notification type
NOTIFICATIONTYPE=jamf
# options:
#   - jamf				show notifications using the jamf Management Action binary
#   - swiftdialog       show notifications using swiftdialog
#   - applescript       show notifications using applescript

# Notification Sources
jamfManagementAction="/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action"
swiftDialog="/usr/local/bin/dialog"
swiftDialogNotification=mini

# - appVersionKey: (optional)
#   How we get version number from app. Default value
#     - CFBundleShortVersionString
#   other values
#     - CFBundleVersion
appVersionKey="CFBundleShortVersionString"
appBundleIdentifierKey="CFBundleIdentifier"

# ignore deletion of files in user directories
IGNORE_USER_DIRS=0
# options:
# 0            delete files/directories in user directories
# 1            ignore deletion of files in user directories, with exception of LaunchAgents
BUILD_DATE="2025-01-23"

# MARK: Functions

printlog() {
  timestamp=$(/bin/date +%F\ %T)
  
  if [ "$(whoami)" = "root" ]; then
    echo "$timestamp" "$1" | tee -a "$logLocation"
  else
    echo "$timestamp" "$1"
  fi
}

runAsUser() {
  if [ "$loggedInUser" != "loginwindow" ]; then
    uid=$(id -u "$loggedInUser")
    /bin/launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"
  fi
}

quitApp() {
  processStatus=$( /usr/bin/pgrep -x "$process")
  if [ "$processStatus" ]; then
    printlog "Found blocking process $process"
    
    if [ "$DEBUG" -eq 0 ]; then
      printlog "Stopping process $process"
      #runAsUser osascript -e "tell app \"$process\" to quit"
      # pkill "$process"
      /usr/bin/killall "$process"
      # small delay after kill action
      sleep 3
    fi
  else
    printlog "Found no blocking process..."
  fi
}

removeFileDirectory() { # $1: object $2: logmode
    object=${1:-"Object"}
    logmode=${2:-"Log Mode"}
  if [ -f "$object" ]; then
    # file exists and can be removed
    printlog "Removing file $object"
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -f "$object"
    fi
  elif [ -d "$object" ]; then
    # it is not a file, it is a directory and can be removed
    printlog "Removing directory $object..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -Rf "$object"
    fi
  elif [ -L "$object" ]; then
    # it is an alias
    printlog "Removing alias $object..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -f "$object"
    fi
  else
    # it is not a file, alias or a directory. Don't remove.
    if [ "$logmode" != "silent" ]; then
    	printlog "INFO: $object is not an existing file or folder"
    fi
  fi
}

removeLaunchDaemons() {
  # remove LaunchDaemon
  if [ -f "$launchDaemon" ]; then
    # LaunchDaemon exists and can be removed
    printlog "Removing launchDaemon $launchDaemon..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/launchctl unload "$launchDaemon"
      /bin/rm -Rf "$launchDaemon"
    fi
  fi
}

removeLaunchAgents() { # $1: object
    object=${1:-"Object"}
  # remove launchAgent
  if [ -f "$object" ]; then
    # launchAgent exists and can be removed
    
    if [ "$DEBUG" -eq 0 ]; then
   		service_name=$(defaults read $object Label)
		rootfolder=$(echo $object | awk -F/ '{print $2}')
		if [[ "$rootfolder" == "Users" ]]; then
			user_name=$(echo $object | awk -F/ '{print $3}')
		else
			user_name=$loggedInUser
		fi
		
		user_uid=$( /usr/bin/id -u "$user_name" )	
		# unload
    	if launchctl print "gui/${user_uid}/${service_name}" &> /dev/null ; then
    		printlog "unloading $object for $user_name"
    		launchctl bootout gui/${user_uid} "$object" &> /dev/null
    		# or the old fashioned way
      		#/bin/launchctl asuser "$user_uid" launchctl unload -F "$object"
		fi
		printlog "Removing launchAgent $object..."
    	/bin/rm -Rf "$object"
    fi
  fi
}

displayNotification() { # $1: message $2: title
  
  message=${1:-"Message"}
  title=${2:-"Notification"}
  FallBacktoAS=false
  
  case $NOTIFICATIONTYPE in
    jamf)
      if [ -x "$jamfManagementAction" ]; then
        "$jamfManagementAction" -message "$message" -title "$title"
      else
        printlog "ERROR: $jamfManagementAction not installed for showing notifications. Falling back to AppleScript"
        FallBacktoAS=true
      fi
    ;;
    swiftdialog)
      if [ -x "$swiftDialog" ]; then
        "$swiftDialog" --message "$message" --title "$title" --$swiftDialogNotification
      else
        printlog "ERROR: $swiftDialog not installed for showing notifications.  Falling back to AppleScript"
        FallBacktoAS=true
      fi
    ;;
    applescript)
      FallBacktoAS=true
    ;;		
    *) # unknown NOTIFICATIONTYPE, using applescript
      FallBacktoAS=true
    ;;
  esac
  
  if [[ "$FallBacktoAS" == true ]]; then
  	runAsUser osascript -e "display notification \"$message\" with title \"$title\""
  fi
  
}

# MARK: Arguments

# Argument parsing
if [ "$1" = "/" ]; then
  # jamf uses sends '/' as the first argument
  shift 3
fi

if [ "$1" != "" ]; then
  label=$1
else
  label=""
fi

# lowercase the label
label=${label:l}

# get loggedInUser user
loggedInUser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ { print $3 }' )
loggedInUserID=$( /usr/bin/id -u "$loggedInUser" )

# Logging
logLocation="/private/var/log/uninstaller.log"



if [[ $# -eq 0 ]]; then
  # "no label as argument -> show all labels
  grep -E '^[a-z0-9\_-]*(\)|\|\\)$' "$0" | tr -d ')' | sort
  exit 0
fi

# check for root
if [ "$(whoami)" != "root" ]; then
  echo "not running as root, exiting"
  exit 1
fi


# Check which event is triggered and add extra information.
case $1 in
1password7)
# Needs more testing
      appTitle="1Password"
      appProcesses+=("1Password 7")
      appProcesses+=("1Password Extension Helper")
      appProcesses+=("1password")
      appFiles+=("/Applications/1Password 7.app")
      appFiles+=("<<Users>>/Library/Application Support/1Password")
      appFiles+=("<<Users>>/Library/Preferences/com.agilebits.onepassword.plist")
      appFiles+=("<<Users>>/Library/Containers/1Password")
      appFiles+=("<<Users>>/Library/Containers/1Password 7")
      appFiles+=("<<Users>>/Library/Containers/1Password Launcher")
      appFiles+=("<<Users>>/Library/Containers/2BUA8C4S2C.com.agilebits.onepassword7-helper")
      appFiles+=("<<Users>>/Library/Group Containers/2BUA8C4S2C.com.agilebits")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.agilebits.onepassword7-updater")
      appFiles+=("<<Users>>/Library/Logs/1Password")
      appFiles+=("<<Users>>/Library/Application Scripts/2BUA8C4S2C.com.agilebits")
      appFiles+=("<<Users>>/Library/Application Scripts/2BUA8C4S2C.com.agilebits.onepassword7-helper")
      appFiles+=("<<Users>>/Library/Application Scripts/com.agilebits.onepassword7")
      appFiles+=("<<Users>>/Library/Application Scripts/com.agilebits.onepassword7-launcher")
      appFiles+=("<<Users>>/Library/Application Scripts/com.agilebits.onepassword7.1PasswordSafariAppExtension")
      appFiles+=("<<Users>>/Library/Application Scripts/com.agilebits.onepasswordslsnativemessaginghost")
      appFiles+=("<<Users>>/Library/Caches/com.agilebits.onepassword7-updater")
      appFiles+=("<<Users>>/Library/Caches/com.apple.Safari/Extensions/")
      appFiles+=("<<Users>>/Library/WebKit/com.agilebits.onepassword4/")
      ;;
1password8)
# Needs more testing
      appTitle="1Password"
      appProcesses+=("1Password")
      appProcesses+=("1Password Extension Helper")
      appProcesses+=("1password")
      appFiles+=("/Applications/1Password.app")
      appFiles+=("<<Users>>/Library/Application Support/1Password")
      appFiles+=("<<Users>>/Library/Preferences/com.agilebits.onepassword.plist")
      appFiles+=("<<Users>>/Library/Containers/1Password")
      appFiles+=("<<Users>>/Library/Containers/1Password 8")
      appFiles+=("<<Users>>/Library/Containers/1Password Launcher")
      appFiles+=("<<Users>>/Library/Group Containers/2BUA8C4S2C.com.agilebits")
      appFiles+=("<<Users>>/Library/Logs/1Password")
      appFiles+=("<<Users>>/Library/Application Scripts/2BUA8C4S2C.com.agilebits")
      appFiles+=("<<Users>>/Library/Application Scripts/2BUA8C4S2C.com.agilebits.onepassword-helper")
      appFiles+=("<<Users>>/Library/Application Scripts/com.agilebits.onepassword")
      appFiles+=("<<Users>>/Library/Application Scripts/com.agilebits.onepassword-launcher")
      appFiles+=("<<Users>>/Library/Application Scripts/com.agilebits.onepassword.1PasswordSafariAppExtension")
      appFiles+=("<<Users>>/Library/Application Scripts/com.agilebits.onepasswordslsnativemessaginghost")
      ;;
3cxdesktopapp)
      appTitle="3CX Desktop App"
      appProcesses+=("3CX Desktop App")
      appFiles+=("/Applications/3CX Desktop App.app")
      appFiles+=("<<Users>>/Library/Application Support/3CX Desktop App")
      appFiles+=("<<Users>>/Library/Preferences/com.electron.3cx-desktop-app.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.electron.3cx-desktop-app.savedState")
      appFiles+=("<<Users>>/Library/Logs/3CX Desktop App")
      appReceipts+=("com.electron.3cx-desktop-app")
      ;;
abstract)
      appTitle="Abstract"
      appProcesses+=("Abstract")
      appFiles+=("/Applications/Abstract.app")
      appFiles+=("<<Users>>/Library/Preferences/com.elasticprojects.abstract-desktop.plist")
      appFiles+=("<<Users>>/Library/Application Support/Abstract")
      appFiles+=("<<Users>>/Library/Caches/com.elasticprojects.abstract-desktop")
      appFiles+=("<<Users>>/Library/Caches/com.elasticprojects.abstract-desktop.ShipIt")
      appFiles+=("<<Users>>/Library/Saved Application State/Abstract")
      ;;
adobedigitaleditions)
# Needs more testing
      appTitle="Adobe Digital Editions"
      appProcesses+=("Adobe Digital Editions")
      appFiles+=("/Applications/Adobe Digital Editions.app")
      adobedigitaleditionsSymlinkDestination=$(readlink "/Applications/Adobe Digital Editions.app")
      appFiles+=("${adobedigitaleditionsSymlinkDestination}")
      appFiles+=("<<Users>>/Library/Preferences/com.adobe.adobedigitaleditions.app.plist")
      ;;
adobereaderdc)
      appTitle="Adobe Acrobat Reader"
      appProcesses+=("AdobeReader")
      appFiles+=("/Applications/Adobe Acrobat Reader.app")
      appFiles+=("/Library/Preferences/com.adobe.reader.DC.WebResource.plist")
      appFiles+=("<<Users>>/Library/Caches/com.adobe.Reader")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.adobe.Reader")
      appFiles+=("<<Users>>/Library/Preferences/com.adobe.Reader.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.adobe.Reader.savedState")
      ;;
androidfiletransfer)
      appTitle="Android File Transfer"
      appProcesses+=("Android File Transfer")
      appProcesses+=("Android File Transfer Agent")
      appFiles+=("/Applications/Android File Transfer.app")
      appFiles+=("<<Users>>/Library/Preferences/com.google.android.mtpviewer.plist")
      ;;
androidstudio)
      appTitle="Android Studio"
      appProcesses+=("Android Studio" "studio")
      appFiles+=("/Applications/Android Studio.app")
      appFiles+=("<<Users>>/.android")
      appFiles+=("<<Users>>/Library/Saved Application State/com.google.android.studio.savedState")
      appFiles+=("<<Users>>/Library/Logs/Google/AndroidStudio2021.3")
      appFiles+=("<<Users>>/Library/Preferences/com.google.android.studio.plist")
      ;;
androidstudiosdk)
      appTitle="Android Studio SDK"
      appFiles+=("<<Users>>/Library/Android/sdk")
      ;;
apparency)
      # credit: pmex
      appTitle="Apparency"
      appProcesses+=( "Apparency" "com.mothersruin.MRSFoundation.UpdateCheckingService" )
      appFiles+=("/Applications/Apparency.app")
      appFiles+=("<<Users>>/Library/Containers/com.mothersruin.Apparency")
      appFiles+=("<<Users>>/Library/Containers/com.mothersruin.Apparency.QLPreviewExtension")
      appFiles+=("<<Users>>/Library/Containers/com.mothersruin.MRSFoundation.UpdateCheckingService")
      appFiles+=("<<Users>>/Library/Application Scripts/com.mothersruin.Apparency")
      appFiles+=("<<Users>>/Library/Application Scripts/com.mothersruin.Apparency.QLPreviewExtension")
      appFiles+=("<<Users>>/Library/Application Scripts/com.mothersruin.MRSFoundation.UpdateCheckingService")
      ;;
appcleaner)
      appTitle="AppCleaner"
      appProcesses+=("AppCleaner")
      appFiles+=("/Applications/AppCleaner.app")
      appFiles+=("<<Users>>/Library/HTTPStorages/net.freemacsoft.AppCleaner")
      appFiles+=("<<Users>>/Library/Preferences/net.freemacsoft.AppCleaner.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/net.freemacsoft.AppCleaner.savedState")
      ;;
applepibaker)
      appTitle="ApplePiBaker"
      appFiles+=("/Applications/ApplePiBaker.app")
      appFiles+=("/Library/LaunchDaemons/com.tweaking4all.ApplePiBakerHelper.plist")
      appFiles+=("/Library/PrivilegedHelperTools/com.tweaking4all.ApplePiBakerHelper")
      appFiles+=("<<Users>>/Library/Preferences/com.tweaking4all.ApplePiBaker.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.tweaking4all.ApplePiBaker.savedState")
      ;;
arc)
      appTitle="Arc"      
      appProcesses+=("Arc" "Arc Helper" "Arc Helper (GPU)")
      appFiles+=("/Applications/Arc.app")
      appFiles+=("<<Users>>/Library/Application Support/Arc")
      appFiles+=("<<Users>>/Library/Caches/Arc")
      appFiles+=("<<Users>>/Library/Caches/company.thebrowser.Browser")
      appFiles+=("<<Users>>/Library/HTTPStorages/company.thebrowser.Browser")
      appFiles+=("<<Users>>/Library/Preferences/company.thebrowser.Browser.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/company.thebrowser.Browser.savedState")
      appFiles+=("<<Users>>/Library/WebKit/company.thebrowser.Browser")
      appReceipts+=("company.thebrowser.Browser")
      ;;
asana)
      appTitle="Asana"
      appProcesses+=("Asana")
      appFiles+=("/Applications/Asana.app")
      appFiles+=("<<Users>>/Library/Application Support/Asana")
      appFiles+=("<<Users>>/Library/Caches/com.electron.asana")
      appFiles+=("<<Users>>/Library/Caches/com.electron.asana.ShipIt")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.electron.asana")
      appFiles+=("<<Users>>/Library/Logs/Asana")
      appFiles+=("<<Users>>/Library/Preferences/com.electron.asana.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.electron.asana.savedState")
      appReceipts+=("com.electron.asana")
      ;;
atom)
      appTitle="Atom"
      appProcesses+=("Atom")
      appFiles+=("/Applications/Atom.app")
      appFiles+=("<<Users>>/Library/Preferences/com.github.atom.plist")
      appFiles+=("<<Users>>/.atom")
      appFiles+=("<<Users>>/Library/Application Support/Atom")
      appFiles+=("<<Users>>/Library/Caches/com.github.atom")
      appFiles+=("<<Users>>/Library/Caches/com.github.atom.ShipIt")
      appFiles+=("<<Users>>/Library/Saved Application State/com.github.atom.savedState")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.github.atom")
      ;;
autopkgr)
      appTitle="AutoPkgr"
      appProcesses+=("AutoPkgr")
      appFiles+=("/Applications/AutoPkgr.app")   
      appLaunchDaemons+=("/Library/LaunchDaemons/com.lindegroup.AutoPkgr.helper.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.lindegroup.AutoPkgr.schedule.plist")
      appFiles+=("/Library/PrivilegedHelperTools/com.lindegroup.AutoPkgr.helper")
      appFiles+=("<<Users>>/Library/Preferences/com.lindegroup.AutoPkgr.plist")
      appFiles+=("<<Users>>/Library/Application Support/AutoPkgr")
      appFiles+=("<<Users>>/Library/Caches/com.lindegroup.AutoPkgr")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.lindegroup.AutoPkgr")
      ;;
azuredatastudio)
      appTitle="Azure Data Studio"
      # Azure Data Studio runs as process Electron. Killing every Electron may be to dangerous
      # so i'm using a preflightCommand for that
      appProcesses+=("Azure Data Studio")
      appFiles+=("/Applications/Azure Data Studio.app")
      appFiles+=("<<Users>>/Library/Application Support/azuredatastudio")
      appFiles+=("<<Users>>/Library/Caches/com.azuredatastudio.oss")
      appFiles+=("<<Users>>/Library/Caches/com.azuredatastudio.oss.ShipIt")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.azuredatastudio.oss")
      appFiles+=("<<Users>>/Library/Preferences/com.azuredatastudio.oss.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.azuredatastudio.oss.savedState")
      preflightCommand+=("kill -9 $(pgrep -f /Applications/Azure\ Data\ Studio.app/Contents/MacOS/Electron)")
      ;;
bbedit)
      appTitle="BBEdit"
      appProcesses+=("BBEdit")
      appFiles+=("/Applications/BBEdit.app")
      appFiles+=("<<Users>>/Library/Application Support/BBEdit")
      appFiles+=("<<Users>>/Library/Preferences/com.barebones.bbedit.plist")
      appFiles+=("<<Users>>/Library/Containers/com.barebones.bbedit")
      appFiles+=("<<Users>>/Library/Application Scripts/com.barebones.bbedit")
      appFiles+=("<<Users>>/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.barebones.bbedit.sfl2")
      appFiles+=("/usr/local/bin/bbdiff")
      appFiles+=("/usr/local/bin/bbedit")
      appFiles+=("/usr/local/bin/bbfind")
      appFiles+=("/usr/local/bin/bbresults")      
      postflightCommand+=("rm -r /Users/$loggedInUser/Library/Caches/com.apple.helpd/Generated/com.barebones.bbedit.help*")
      ;;
blender)
      appTitle="Blender"
      appProcesses+=("Blender")
      appFiles+=("/Applications/Blender.app")
      appFiles+=("<<Users>>/Library/Application Support/Blender")
      ;;
boxdrive)
      appTitle="Box Drive"
      appProcesses+=("Box")
      appFiles+=("/Applications/Box.app")
      appFiles+=("/Library/Application Support/Box")
      appLaunchAgents+=("/Library/LaunchAgents/com.box.desktop.helper.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.box.desktop.autoupdater.plist")
      appFiles+=("/Library/Logs/Box")
      appFiles+=("/Library/Preferences/com.box.desktop.plist")
      appFiles+=("<<Users>>/Library/Application Scripts/com.box.desktop.boxfileprovider")
      appFiles+=("<<Users>>/Library/Application Scripts/com.box.desktop.findersyncext")
      appFiles+=("<<Users>>/Library/Application Support/Box")
      appFiles+=("<<Users>>/Library/Containers/com.box.desktop.boxfileprovider")
      appFiles+=("<<Users>>/Library/Containers/com.box.desktop.findersyncext")
      appFiles+=("<<Users>>/Library/Group Containers/M683GB7CPW.b")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.box.desktop.launch.plist")
      appFiles+=("<<Users>>/Library/Logs/Box")
      appFiles+=("<<Users>>/Library/Logs/Box/Box/com.box.desktop.ui-stderr.txt")
      appFiles+=("<<Users>>/Library/Preferences/com.box.desktop.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.box.desktop.ui.plist")
      appReceipts+=("com.box.desktop.installer.autoupdater")
      appReceipts+=("com.box.desktop.installer.desktop")
      appReceipts+=("com.box.desktop.installer.local.appsupport")
      ;;
boxsync)
      appTitle="Box Sync"
      appProcesses+=("Box Sync")
      appFiles+=("/Applications/Box Sync.app")
      appFiles+=("/Library/PrivilegedHelperTools/com.box.sync.bootstrapper")
      appFiles+=("<<Users>>/Library/Application Scripts/com.box.sync.findersyncext")
      appFiles+=("<<Users>>/Library/Application Scripts/M683GB7CPW.com.box.sync")
      appFiles+=("<<Users>>/Library/Application Support/Box")
      appFiles+=("<<Users>>/Library/Caches/com.box.sync")
      appFiles+=("<<Users>>/Library/Containers/com.box.sync.findersyncext")
      appFiles+=("<<Users>>/Library/Group Containers/M683GB7CPW.com.box.sync")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.box.sync")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.box.sync.binarycookies")
      appFiles+=("<<Users>>/Library/Logs/Box/Box Sync")
      appFiles+=("<<Users>>/Library/Preferences/com.box.sync.plist")
      # Box Data is placed by default in ~/Box Sync
      # if you really want to remove this data you can uncomment the next line
      # appFiles+=("<<Users>>/Box Sync")
      ;;
boxtools)
      appTitle="Box Tools"
      appProcesses+=("Box Edit" "Box Local Com Server" "Box Tools Custom Apps" "Box Device Trust")
      appFiles+=("/Library/Application Support/Box/Box Edit/Box Device Trust.app")
      appFiles+=("/Library/Application Support/Box/Box Edit/Box Edit.app")
      appFiles+=("/Library/Application Support/Box/Box Edit/Box Local Com Server.app")
      appFiles+=("/Library/Application Support/Box/Box Edit/Box Tools Custom Apps.app")
      appFiles+=("/Library/Application Support/Box")
      appFiles+=("/Library/Preferences/com.box.deviceId.plist")
      appFiles+=("<<Users>>/Library/Application Scripts/com.Box.Box-Edit.BoxEditFinderExtension")
      appFiles+=("<<Users>>/Library/Caches/com.Box.Box-Edit")
      appFiles+=("<<Users>>/Library/Containers/com.Box.Box-Edit.BoxEditFinderExtension")
      appFiles+=("<<Users>>/Library/Group Containers/M683GB7CPW.com.box.tools")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.Box.Box-Edit")
      appFiles+=("<<Users>>/Library/Logs/Box")
      appFiles+=("<<Users>>/Library/Logs/Box/Box Local Com Server")
      appFiles+=("<<Users>>/Library/Preferences/com.Box.Box-Edit.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.box.Box-Local-Com-Server.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.box.Box-Device-Trust.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.Box.Box-Edit.launch.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.box.Box-Local-Com-Server.launch.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.box.Box-Device-Trust.launch.plist")
      appReceipts+=("com.box.boxtools.installer.boxcustomapps")
      appReceipts+=("com.box.boxtools.installer.boxdevicetrust")
      appReceipts+=("com.box.boxtools.installer.boxedit")
      appReceipts+=("com.box.boxtools.installer.boxlocalcomserver")
      ;;
chatgpt)
      appTitle="ChatGPT"      
      appProcesses+=("ChatGPT")
      appFiles+=("/Applications/ChatGPT.app")
      appFiles+=("<<Users>>/Library/Application Support/ChatGPT")
      appFiles+=("<<Users>>/Library/Application Support/com.openai.chat")
      appFiles+=("<<Users>>/Library/Caches/com.openai.chat")
      appFiles+=("<<Users>>/Library/Group Containers/group.com.openai.chat")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.openai.chat")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.openai.chat.binarycookies")
      appFiles+=("<<Users>>/Library/Preferences/com.openai.chat.RemoteFeatureFlags.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.openai.chat.StatsigService.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.openai.chat.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.openai.chat")
      ;;
cinema4d2023)
      # credit: pmex
      appTitle="Cinema 4D 2023"
      appProcesses+=("Cinema 4D")
      appFiles+=("/Applications/Maxon Cinema 4D 2023")
      appFiles+=("<<Users>>//Library/Caches/net.maxon.cinema4d")
      appFiles+=("<<Users>>/Library/HTTPStorages/net.maxon.cinema4d")
      appFiles+=("<<Users>>/Library/Preferences/Maxon/Maxon Cinema 4D 2023_3BE69839")
      appFiles+=("<<Users>>/Library/Preferences/net.maxon.cinema4d.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/net.maxon.cinema4d.savedState")
      ;;
cinema4d2024)
      # credit: pmex
      appTitle="Cinema 4D 2024"
      appProcesses+=("Cinema 4D")
      appFiles+=("/Applications/Maxon Cinema 4D 2024")
      appFiles+=("<<Users>>//Library/Caches/net.maxon.cinema4d")
      appFiles+=("<<Users>>/Library/HTTPStorages/net.maxon.cinema4d")
      appFiles+=("<<Users>>/Library/Preferences/Maxon/Maxon Cinema 4D 2024_22E620F3")
      appFiles+=("<<Users>>/Library/Preferences/net.maxon.cinema4d.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/net.maxon.cinema4d.savedState")
      ;;
cinema4d2025)
      # credit: copy from cinema4d2024 from pmex
      appTitle="Cinema 4D 2025"
      appProcesses+=("Cinema 4D")
      appFiles+=("/Applications/Maxon Cinema 4D 2025")
      appFiles+=("<<Users>>//Library/Caches/net.maxon.cinema4d")
      appFiles+=("<<Users>>/Library/HTTPStorages/net.maxon.cinema4d")
      appFiles+=("<<Users>>/Library/Preferences/Maxon/Maxon Cinema 4D 2025_FFA38A4B")
      appFiles+=("<<Users>>/Library/Preferences/net.maxon.cinema4d.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/net.maxon.cinema4d.savedState")
      ;;
citrixworkspace)
      appTitle="Citrix Workspace"
      appFiles+=("/Applications/Citrix Workspace.app")
      appFiles+=("/Library/Application Support/Citrix Workspace Updater")
      appFiles+=("/Library/Application Support/Citrix Receiver")
      appFiles+=("/Library/Application Support/Citrix")
      appFiles+=("/Library/Application Support/Citrix Enterprise Browser")
      appFiles+=("<<Users>>/Library/Application Support/Citrix Workspace")
      appFiles+=("<<Users>>/Library/Application Support/Citrix Receiver")
      appFiles+=("<<Users>>/Library/Application Support/Citrix")
      appFiles+=("<<Users>>/Library/Application Support/com.citrix.receiver.helper")
      appFiles+=("<<Users>>/Library/Application Support/com.citrix.receiver.nomas")
      appFiles+=("<<Users>>/Library/Caches/com.citrix.receiver.nomas")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.citrix.receiver.nomas")
      appFiles+=("<<Users>>/Library/Logs/Citrix Workspace")
      appFiles+=("<<Users>>/Library/Preferences/com.citrix.receiver.nomas.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.citrix.receiver.nomas")
      appFiles+=("<<Users>>/Library/Saved Application State/com.citrix.receiver.nomas.savedState")
      appFiles+=("/Library//Library/Preferences/com.citrix.apps.configuration.plist")
      appFiles+=("/usr/local/libexec/AuthManager_Mac.app")
      appFiles+=("/usr/local/libexec/Citrix Workspace Helper.app")
      appFiles+=("/usr/local/libexec/ServiceRecords.app")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.citrix.ctxusbd.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.citrix.ctxworkspaceupdater.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.citrix.CtxWorkspaceHelperDaemon.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.citrix.AuthManager_Mac.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.citrix.ReceiverHelper.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.citrix.safariadapter.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.citrix.ServiceRecords.plist")
      appReceipts+=("com.citrix.workspace.app.pkg")
      appReceipts+=("com.citrix.ICAClient")
      appReceipts+=("com.citrix.common")
      appReceipts+=("com.citrix.ICAClientcwa")
      appReceipts+=("com.citrix.enterprisebrowserinstaller")
      appReceipts+=("com.citrix.ICAClienthdx")
      ;;
coderunner)
      appTitle="CodeRunner"
      appProcesses+=("CodeRunner")
      appFiles+=("/Applications/CodeRunner.app")
      appFiles+=("<<Users>>/Library/Application Support/CodeRunner")
      appFiles+=("<<Users>>/Library/Caches/com.krill.CodeRunner")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.krill.CodeRunner")
      appFiles+=("<<Users>>/Library/Preferences/com.krill.CodeRunner.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.krill.CodeRunner")
      appFiles+=("<<Users>>/Library/Saved Application State/com.krill.CodeRunner.savedState")
      ;;
connectfonts)
	appTitle="Connect Fonts"
	appProcesses+=("Connect Fonts")
	appFiles+=("/Applications/Connect Fonts.app")
	appLaunchDaemons+=("/Library/LaunchDaemons/com.extensis.plugin-install-helper.plist")
	appFiles+=("/Library/PrivilegedHelperTools/com.extensis.plugin-install-helper")
	appFiles+=("<<Users>>/Library/Caches/com.extensis.SuitcaseFusion")
	;;
cyberduck)
      appTitle="Cyberduck"
      appProcesses+=("Cyberduck")
      appFiles+=("/Applications/Cyberduck.app")
      appFiles+=("<<Users>>/Library/Preferences/ch.sudo.cyberduck.plist")
      appFiles+=("<<Users>>/Library/Application Support/Cyberduck")
      appFiles+=("<<Users>>/Library/Group Containers/G69SCX94XU.duck/Library/Application Support/duck")
      appFiles+=("<<Users>>/Library/Logs/Cyberduck")
      appFiles+=("<<Users>>/Library/HTTPStorages/ch.sudo.cyberduck")
      appFiles+=("<<Users>>/Library/Saved Application State/ch.sudo.cyberduck.savedState")
      ;;
deezer)
      appTitle="Deezer"      
      appProcesses+=("Deezer")
      appFiles+=("/Applications/Deezer.app")
      appFiles+=("<<Users>>/Library/Application Support/deezer-desktop")
      appFiles+=("<<Users>>/Library/Logs/Deezer")
      appFiles+=("<<Users>>/Library/Preferences/com.deezer.deezer-desktop.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.deezer.deezer-desktop.savedState")
      appReceipts+=("com.deezer.deezer-desktop.bom")
      ;;
depnotify)
      appTitle="DEPNotify"
      appProcesses+=("DEPNotify")
      appFiles+=("/Applications/Utilities/DEPNotify.app")
      appFiles+=("<<Users>>/Library/Preferences/menu.nomad.DEPNotify.plist")
      appFiles+=("<<Users>>/Library/Caches/menu.nomad.DEPNotify")
      appFiles+=("<<Users>>/Library/WebKit/menu.nomad.DEPNotify")
      appFiles+=("/var/tmp/com.depnotify.provisioning.done")
      appFiles+=("/var/tmp/depnotify.log")
      appFiles+=("/var/tmp/depnotifyDebug.log")
      appReceipts+=("menu.nomad.depnotify")
      ;;
desktoppr)
      appTitle="Desktoppr"
      appFiles+=("/usr/local/bin/desktoppr")
      appReceipts+=("com.scriptingosx.desktoppr")
      ;;
dfublaster)
      appTitle="DFU Blaster"
      appProcesses+=("DFU Blaster")
      appFiles+=("/Applications/DFU Blaster.app")
      appFiles+=("/Library/LaunchDaemons/com.twocanoes.dfublasterhelper.plist")
      appFiles+=("/Library/PrivilegedHelperTools/com.twocanoes.dfublasterhelper")
      appFiles+=("<<Users>>/Library/Preferences/com.twocanoes.DFU-Blaster.plist")
      ;;
displaylinkmanager)
      appTitle="DisplayLinkUserAgent"
      appFiles+=("/Applications/DisplayLink Manager.app")
      appFiles+=("<<Users>>/Library/Application Scripts/com.displaylink.DisplayLinkLoginHelper")
      appFiles+=("<<Users>>/Library/Application Scripts/com.displaylink.DisplayLinkUserAgent")
      appFiles+=("<<Users>>/Library/Containers/com.displaylink.DisplayLinkLoginHelper")
      appFiles+=("<<Users>>/Library/Containers/com.displaylink.DisplayLinkUserAgent")
      appFiles+=("<<Users>>/Library/Group Containers/73YQY62QM3.com.displaylink.DisplayLinkShared")
      appReceipts+=("com.displaylink.displaylinkmanagerapp")
      ;;
dockutil)
      appTitle="Dockutil"
      appFiles+=("/usr/local/bin/dockutil")
      appReceipts+=("dockutil.cli.tool")
      ;;
drawio)
      appTitle="Draw.io"
      appProcesses+=("draw.io")
      appFiles+=("/Applications/draw.io.app")
      appFiles+=("<<Users>>/Library/Application Support/draw.io")
      appFiles+=("<<Users>>/Library/Preferences/com.jgraph.drawio.desktop.plist")
      appFiles+=("<<Users>>/Library/Caches/com.jgraph.drawio.desktop.ShipIt")
      appFiles+=("<<Users>>/Library/Caches/com.jgraph.drawio.desktop")
      appFiles+=("<<Users>>/Library/Logs/draw.io")
      appFiles+=("<<Users>>/Library/Saved Application State/com.jgraph.drawio.desktop.savedState")
      ;;
dropbox)
      appTitle="Dropbox"
      appProcesses+=("Dropbox")
      appFiles+=("/Applications/Dropbox.app")
      appFiles+=("<<Users>>/.dropbox")
      appFiles+=("<<Users>>/Library/Application Scripts/com.getdropbox.dropbox.TransferExtension")
      appFiles+=("<<Users>>/Library/Application Scripts/com.getdropbox.dropbox.fileprovider")
      appFiles+=("<<Users>>/Library/Application Scripts/com.getdropbox.dropbox.garcon")
      appFiles+=("<<Users>>/Library/Application Scripts/com.dropbox.alternatenotificationservice")
      appFiles+=("<<Users>>/Library/Application Scripts/com.dropbox.client.crashpad")
      appFiles+=("<<Users>>/Library/Application Scripts/G7HH3F8CAK.com.getdropbox.dropbox.sync")
      appFiles+=("<<Users>>/Library/Application Support/Dropbox")
      appFiles+=("<<Users>>/Library/QuickLook/DropboxQL.qlgenerator")
      #appFiles+=("<<Users>>/Library/Application Support/FileProvider/com.getdropbox.dropbox.fileprovider")
      appFiles+=("<<Users>>/Library/Containers/com.getdropbox.dropbox.TransferExtension")
      appFiles+=("<<Users>>/Library/Containers/com.getdropbox.dropbox.fileprovider")
      appFiles+=("<<Users>>/Library/Containers/com.getdropbox.dropbox.garcon")
      appFiles+=("<<Users>>/Library/Containers/com.dropbox.alternatenotificationservice")
      appFiles+=("<<Users>>/Library/Dropbox")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.dropbox.DropboxMacUpdate")
      appFiles+=("<<Users>>/Library/Group Containers/G7HH3F8CAK.com.getdropbox.dropbox.sync")
      appFiles+=("<<Users>>/Library/Group Containers/com.dropbox.client.crashpad")
      appFiles+=("<<Users>>/Library/Preferences/com.dropbox.DropboxMacUpdate.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.getdropbox.dropbox.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.dropbox.DropboxMacUpdate.agent.plist")
      ;;
dymoconnect)
      appTitle="DYMO Connect"
      appFiles+=("/Applications/DYMO Connect.app")
      appFiles+=("/Applications/DYMO Connect Support Tool.app")
      appFiles+=("/Applications/DYMO.WebApi.Mac.Host.app")
      appFiles+=("<<Users>>/Library/DYMOConnect")
      appFiles+=("/Library/PrivilegedHelperTools/com.dymo.dymo-connect.helper")
      appFiles+=("<<Users>>/Library/Preferences/com.dymo.dymo-connect.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.dymo.dcd.webservice.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.dymo.dymo-connect.helper.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.dymo.pnpd.plist")
      appReceipts+=("com.dymo.dymo-connect")
      ;;
easyfind)
      appTitle="EasyFind"
      appProcesses+=("EasyFind")
      appFiles+=("/Applications/EasyFind.app")
      appFiles+=("<<Users>>/Library/Application Support/EasyFind")
      appFiles+=("<<Users>>/Library/Preferences/org.grunenberg.EasyFind.plist")
      ;;
elgatocamerahub)
      appTitle="Elgato Camera Hub"
      appProcesses+=("Elgato Camera Hub")
      appProcesses+=("avconferenced")
      appFiles+=("/Applications/Elgato Camera Hub.app")
      appFiles+=("/Library/CoreMediaIO/Plug-Ins/DAL/elgatovirtualcamera.plugin")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Elgato/Camera Hub")
      appFiles+=("/Library/Application Support/Elgato/Camera Hub")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.elgato.CameraHub")
      appFiles+=("/Users/$loggedInUser/Library/Logs/CameraHub")
      appLaunchAgents+=("/Users/$loggedInUser/Library/LaunchAgents/com.elgato.CameraHub.plist")
      ;;elgatostreamdeck)
      appTitle="Elgato Stream Deck"
      appFiles+=("/Applications/Elgato Stream Deck.app")
      appProcesses+=("Stream Deck")
      appFiles+=("<<Users>>/Library/Application Support/com.elgato.StreamDeck")
      appFiles+=("<<Users>>/Library/LaunchAgents/com.elgato.StreamDeck.plist")
      appFiles+=("<<Users>>/Library/Logs/ElgatoStreamDeck")
      appReceipts+=("com.elgato.StreamDeck")
      ;;
figma)
      appTitle="Figma"
      appProcesses+=("Figma")
      appFiles+=("/Applications/Figma.app")
      appFiles+=("<<Users>>/Library/Application Support/Figma")
      appFiles+=("<<Users>>/Library/Application Support/figma-desktop")
      appFiles+=("<<Users>>/Library/Preferences/com.figma.Desktop.plist")
      appFiles+=("<<Users>>/Library/Caches/com.figma.agent")
      ;;
filemakerpro16)
      appTitle="FileMaker Pro"
      appProcesses+=("FileMaker Pro")
      appFiles+=("/Applications/Filemaker Pro 16/FileMaker Pro.app")
      appFiles+=("<<Users>>/Library/Caches/com.filemaker.client.pro12")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.filemaker.client.pro12")      
      appFiles+=("<<Users>>/Library/HTTPStorages/com.filemaker.client.pro12.binarycookies")         
      appFiles+=("<<Users>>/Library/Preferences/com.filemaker.client.pro12.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.filemaker.client.pro12.savedState")
      appFiles+=("<<Users>>/Library/Application Support/FileMaker")
      appFiles+=("/Users/Shared/FileMaker/") 
      ;;
filemakerpro19)
      appTitle="FileMaker Pro"
      appProcesses+=("FileMaker Pro")
      appFiles+=("/Applications/FileMaker Pro.app")
      appFiles+=("<<Users>>/Library/Application Support/FileMaker")
      appFiles+=("<<Users>>/Library/Preferences/com.filemaker.client.pro12.plist")
      appFiles+=("<<Users>>/Library/Caches/com.filemaker.client.pro12")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.filemaker.client.pro12")
      appFiles+=("<<Users>>/Library/Saved Application State/com.filemaker.client.pro12.savedState")
      appFiles+=("<<Users>>/Library/WebKit/com.filemaker.client.pro12")
      appFiles+=("/Users/Shared/FileMaker/FileMaker Pro/19.0")
      ;;
filezilla)
      appTitle="FileZilla"
      appProcesses+=("filezilla")
      appFiles+=("/Applications/FileZilla.app")
      appFiles+=("<<Users>>/Library/Preferences/org.filezilla-project.filezilla.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/org.filezilla-project.filezilla.savedState")
      ;;
findanyfile)
      appTitle="Find Any File"
      appProcesses+=("Find Any File")
      appFiles+=("/Applications/Find Any File.app")
      appFiles+=("<<Users>>/Library/Application Support/Find Any File/FAF.log")
      appFiles+=("<<Users>>/Library/Preferences/org.tempel.findanyfile.plist")
      ;;
firefox)
      appTitle="FireFox"
      appProcesses+=("firefox")
      appFiles+=("/Applications/Firefox.app")
      appFiles+=("<<Users>>/Library/Preferences/org.mozilla.firefox.plist")
      appFiles+=("<<Users>>/Library/Caches/Mozilla/updates/Applications/Firefox/macAttributionData")
      appFiles+=("<<Users>>/Library/Caches/Firefox")
      appFiles+=("<<Users>>/Library/Saved Application State/org.mozilla.firefox.savedState")
      ;;
garageband)
      appTitle="GarageBand"
      appProcesses+=("GarageBand")
      appFiles+=("/Applications/GarageBand.app")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.garageband10")
      appFiles+=("<<Users>>/Library/Caches/com.apple.helpd/Generated/com.apple.garageband10.help*10.4.11")
      appFiles+=("<<Users>>/Library/Containers/com.apple.garageband10")
      appReceipts+=("com.apple.pkg.GarageBand_AppStore")
      ;;
gimp)
      # credit: pijpe00
      appTitle="GIMP"
      appReceipts+=("org.gimp.gimp-2.10")
      appProcesses+=("gimp")
      appFiles+=("/Applications/GIMP.app")
      appFiles+=("<<Users>>/Library/Application Support/GIMP")
      appFiles+=("<<Users>>/Library/Caches/org.gimp.gimp-2.10")
      appFiles+=("<<Users>>/Library/HTTPStorages/org.gimp.gimp-2.10")
      appFiles+=("<<Users>>/Library/Preferences/org.gimp.gimp-2.10.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/org.gimp.gimp-2.10.savedState")
      ;;
githubdesktop)
      appTitle="GitHub Desktop"
      appProcesses+=("GitHub Desktop")
      appFiles+=("/Applications/GitHub Desktop.app")
      appFiles+=("<<Users>>/Library/Application Support/GitHub Desktop")
      appFiles+=("<<Users>>/Library/Caches/com.github.GitHubClient")
      appFiles+=("<<Users>>/Library/Caches/com.github.GitHubClient.ShipIt")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.github.GitHubClient")      
      appFiles+=("<<Users>>/Library/Preferences/com.github.GitHubClient.plist")
      appFiles+=("<<Users>>/Library/Logs/GitHub Desktop")
      appFiles+=("<<Users>>/Library/Saved Application State/com.github.GitHubClient.savedState") 
      appReceipts+=("com.github.GitHubClient")
      ;;
gitkraken)
      appTitle="GitKraken"      
      appProcesses+=("GitKraken")
      appFiles+=("/Applications/GitKraken.app")
      appFiles+=("<<Users>>/Library/Application Support/GitKraken")
      appFiles+=("<<Users>>/Library/Caches/com.axosoft.gitkraken")
      appFiles+=("<<Users>>/Library/Caches/com.axosoft.gitkraken.ShipIt")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.axosoft.gitkraken")
      appFiles+=("<<Users>>/Library/Preferences/com.axosoft.gitkraken.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.axosoft.gitkraken.savedState")
      appReceipts+=("com.axosoft.gitkraken")
      ;;
googlechrome)
      appTitle="Google Chrome"
      appProcesses+=("Google Chrome")
      appFiles+=("/Applications/Google Chrome.app")
      appFiles+=("<<Users>>/Library/Application Support/Google/Chrome")
      appFiles+=("<<Users>>/Library/Preferences/com.google.Chrome.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.google.Keystone.Agent.plist")
      appFiles+=("<<Users>>/Library/Caches/com.google.Keystone")
      appFiles+=("<<Users>>/Library/Caches/com.google.SoftwareUpdate")
      appFiles+=("<<Users>>/Library/Caches/Google")
      appFiles+=("<<Users>>/Library/Google")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.google.Keystone")
      appFiles+=("<<Users>>/Library/Saved Application State/com.google.Chrome.savedState")
      appFiles+=("/Library/Google/Chrome")
      appLaunchAgents+=("/Library/LaunchAgents/com.google.keystone.xpcservice.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.google.keystone.agent.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.google.keystone.xpcservice.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.google.keystone.agent.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.google.keystone.system.agent.plist")
      ;;
gotomeeting)
      appTitle="GoToMeeting"
      appProcesses+=("GoToMeeting")
      appFiles+=("/Applications/GoToMeeting.app")
      appFiles+=("<<Users>>/Library/Logs/com.logmein.GoToMeeting")
      appFiles+=("<<Users>>/Library/Preferences/com.logmein.GoToMeeting.plist") 
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.logmein.GoToMeeting.G2MAIRUploader.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.logmein.GoToMeeting.G2MUpdate.plist")
      ;;
gpgsuite)
      appTitle="GPG Suite"
      appReceipts+=("org.gpgtools.key")
      appReceipts+=("org.gpgtools.checkprivatekey.pkg")
      appReceipts+=("org.gpgtools.gpgkeychain.pkg")
      appReceipts+=("org.gpgtools.gpgpreferences.pkg")
      appReceipts+=("org.gpgtools.gpgservices.pkg")
      appReceipts+=("org.gpgtools.libmacgpg.xpc.pkg")
      appReceipts+=("org.gpgtools.libmacgpgB.pkg")
      appReceipts+=("org.gpgtools.macgpg2.1.pkg")
      appReceipts+=("org.gpgtools.pinentry.pkg")
      appReceipts+=("org.gpgtools.pkg.preinstall")
      appReceipts+=("org.gpgtools.pkg.version")
      appReceipts+=("org.gpgtools.updater".pkg)
      appLaunchAgents+=("/Library/LaunchDaemons/org.gpgtools.Libmacgpg.xpc.plist")
      appLaunchAgents+=("/Library/LaunchDaemons/org.gpgtools.gpgmail.patch-uuid-user.plist")
      appLaunchAgents+=("/Library/LaunchDaemons/org.gpgtools.gpgmail.updater.plist")
      appLaunchAgents+=("/Library/LaunchDaemons/org.gpgtools.macgpg2.fix.plist")
      appLaunchAgents+=("/Library/LaunchDaemons/org.gpgtools.macgpg2.shutdown-gpg-agent.plist")
      appLaunchAgents+=("/Library/LaunchDaemons/org.gpgtools.macgpg2.updater.plist")
      appLaunchAgents+=("/Library/LaunchDaemons/org.gpgtools.macgpg2.gpg-agent.plist")
      appLaunchAgents+=("/Library/LaunchDaemons/org.gpgtools.updater.plist")
      appProcesses+=("GPG Keychain")
      appProcesses+=("GPGServices")
      appProcesses+=("gpg-agent")
      appProcesses+=("dirmngr")
      appProcesses+=("gpg")
      appProcesses+=("gpg2")
      appFiles+=("/Applications/GPG Keychain.app")
      appFiles+=("/Applications/GPG Keychain Access.app")
      appFiles+=("/Library/Application Support/GPGTools")
      appFiles+=("/Library/Frameworks/Libmacgpg.framework")
      appFiles+=("/Library/Mail/Bundles/GPGMailLoader*.mailbundle")
      appFiles+=("/Library/PreferencePanes/GPGPreferences.prefPane")
      appFiles+=("/Library/Services/GPGServices.service")
      appFiles+=("/usr/local/MacGPG2")
      appFiles+=("/private/etc/paths.d/MacGPG2")
      appFiles+=("/private/etc/manpaths.d/MacGPG2")
      appFiles+=("/private/tmp/gpg-agent")
      appFiles+=("/usr/local/bin/gpg")
      appFiles+=("/usr/local/bin/gpg2")
      appFiles+=("/usr/local/bin/gpg-agent")
      appFiles+=("<<Users>>/Library/Frameworks/Libmacgpg.framework")
      appFiles+=("<<Users>>/Library/Mail/Bundles/GPGMail.mailbundle")
      appFiles+=("<<Users>>/Library/PreferencePanes/GPGPreferences.prefPane")
      appFiles+=("<<Users>>/Library/Services/GPGServices.service")
      ;;
icons)
      appTitle="Icons"
      appProcesses+=("Icons")
      appFiles+=("/Applications/Icons.app")
      appFiles+=("<<Users>>/Library/Application Scripts/7R5ZEU67FQ.corp.sap.Icons")
      appFiles+=("<<Users>>/Library/Application Scripts/corp.sap.Icons")
      appFiles+=("<<Users>>/Library/Application Scripts/corp.sap.Icons.Make-Icon-Set")
      appFiles+=("<<Users>>/Library/Containers/corp.sap.Icons")
      appFiles+=("<<Users>>/Library/Containers/corp.sap.Icons.Make-Icon-Set")
      appFiles+=("<<Users>>/Library/Group Containers/7R5ZEU67FQ.corp.sap.Icons")
      ;;
iina)
      appTitle="IINA"
      appFiles+=("/Applications/IINA.app")
      appFiles+=("<<Users>>/Library/Application Scripts/com.colliderli.iina.OpenInIINA")
      appFiles+=("<<Users>>/Library/Application Support/com.colliderli.iina")
      appFiles+=("<<Users>>/Library/Caches/com.colliderli.iina")
      appFiles+=("<<Users>>/Library/Containers/com.colliderli.iina.OpenInIINA")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.colliderli.iina")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.colliderli.iina.binarycookies")
      appFiles+=("<<Users>>/Library/Preferences/com.colliderli.iina.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.colliderli.iina")
      ;;
imazingprofileeditor)
      appTitle="iMazing Profile Editor"
      appProcesses+=("iMazing Profile Editor")
      appFiles+=("/Applications/iMazing Profile Editor.app")
      appFiles+=("<<Users>>/Library/Containers/com.DigiDNA.iMazingProfileEditorMac")
      appFiles+=("<<Users>>/Library/Preferences/com.DigiDNA.iMazing2Mac.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.DigiDNA.iMazingProfileEditorMac.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.DigiDNA.iMazing2Mac")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.DigiDNA.iMazing2Mac")
      appFiles+=("<<Users>>/Library/Application Support/com.DigiDNA.iMazing2Mac")
      appFiles+=("<<Users>>/Library/Application Scripts/com.DigiDNA.iMazingProfileEditorMac")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.DigiDNA.iMazingProfileEditorMac")
      appFiles+=("<<Users>>/Library/Application Support/iMazing")
      ;;
imovie)
      appTitle="iMovie"
      appProcesses+=("iMovie")
      appFiles+=("/Applications/iMovie.app")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.iMovieApp")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.videoapps.OOPProResRawService")
      appFiles+=("<<Users>>/Library/Application Support/iMovie")
      appFiles+=("<<Users>>/Library/Containers/com.apple.iMovieApp")
      appFiles+=("<<Users>>/Library/Containers/com.apple.videoapps.OOPProResRawService")
      ;;
installomator)
      appTitle="Installomator"
      appProcesses+=("Installomator")
      appFiles+=("/usr/local/Installomator")
      appFiles+=("/var/log/Installomator.log")
      appReceipts+=("com.scriptingosx.Installomator")
      ;;
iterm2)
      appTitle="iTerm2"
      appProcesses+=("iTerm2")
      appFiles+=("/Applications/iTerm.app")
      appFiles+=("<<Users>>/Library/Application Support/iTerm2")
      appFiles+=("<<Users>>/Library/Preferences/com.googlecode.iterm2.plist")
      ;;
jamfconnect)
      appTitle="Jamf Connect"
      appProcesses+=("Jamf Connect")
      appFiles+=("/Applications/Jamf Connect.app")
      appFiles+=("/Library/Application Support/JamfConnect")
      appFiles+=("/usr/local/bin/authchanger")
      appFiles+=("/usr/local/lib/pam/pam_saml.so.2")
      appFiles+=("/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.connect.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.connect.unlock.login.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.jamf.connect.daemon.plist")
      preflightCommand+=("/usr/local/bin/authchanger -reset")
      ;;
jamfpro)
      appTitle="Jamf Pro"
      appProcesses+=("Composer")
      appProcesses+=("Jamf Admin")
      appProcesses+=("Jamf Remote")
      appProcesses+=("Recon")
      appFiles+=("/Applications/Jamf Pro")
      appFiles+=("<<Users>>/Library/Preferences/com.jamfsoftware.admin.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.jamfsoftware.Composer.plist")
      appFiles+=("/Library/Application Support/JAMF/Composer")
      appFiles+=("<<Users>>/Library/Saved Application State/com.jamfsoftware.Composer.savedState")
      appFiles+=("/Library/PrivilegedHelperTools/com.jamfsoftware.Composer.helper")    
      appLaunchDaemons+=("/Library/LaunchDaemons/com.jamfsoftware.Composer.helper.plist")  
      ;;
jamfprotect)
      appTitle="JamfProtect"
      appFiles+=("/Applications/JamfProtect.app")
      appFiles+=("/Library/Application Support/JamfProtect")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.protect.agent.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.jamf.protect.daemon.plist")
      #preflightCommand+=("/Applications/JamfProtect.app/Contents/MacOS/JamfProtect uninstall")
      ;;
jamftrust)
      appTitle="Jamf Trust"
      appFiles+=("/Applications/Jamf Trust.app")
      appFiles+=("<<Users>>/Library/Application Scripts/com.jamf.trust")
      appFiles+=("<<Users>>/Library/Application Scripts/com.jamf.trust.launcher")
      appFiles+=("<<Users>>/Library/Application Scripts/com.jamf.trust.ne-access")
      appFiles+=("<<Users>>/Library/Containers/com.jamf.trust")
      appFiles+=("<<Users>>/Library/Containers/com.jamf.trust.launcher")
      appFiles+=("<<Users>>/Library/Containers/com.jamf.trust.ne-access")
      appFiles+=("<<Users>>/Library/Group Containers/483DWKW443.com.jamf.trust")
      ;;
java8oracle)
      appTitle="Java 8"
      appProcesses+=("java")
      appFiles+=("/Library/Application Support/Oracle/Java")
      appFiles+=("/Library/Internet Plug-Ins/JavaAppletPlugin.plugin")
      appFiles+=("/Library/PreferencePanes/JavaControlPanel.prefPane")
      appFiles+=("/Library/Preferences/com.oracle.java.Helper-Tool.plist")
      appFiles+=("<<Users>>/Library/Caches/Oracle.MacJREInstaller")    
      appFiles+=("<<Users>>/Library/Application\ Support/Oracle/Java")
      appFiles+=("<<Users>>/Library/Preferences/com.oracle.java.JavaAppletPlugin.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.oracle.javadeployment.plist")
      appFiles+=("<<Users>>/Library/Application Support/Oracle/Java")
      appFiles+=("<<Users>>/Library/Application Support/JREInstaller")                       
      appLaunchAgents+=("/Library/LaunchAgents/com.oracle.java.Java-Updater.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.oracle.java.Helper-Tool.plist")
      appReceipts+=("com.oracle.jre")
      ;;
jetbrainsintellijidea)
      appTitle="IntelliJ IDEA"
      appReceipts+=("com.jetbrains.intellij")
      appProcesses+=("idea")
      appFiles+=("/Applications/IntelliJ IDEA.app")
      appFiles+=("<<Users>>/Library/Preferences/com.jetbrains.intellij.plist")
      ;;
jetbrainspycharm)
      # credit: pijpe00
      appTitle="PyCharm"
      appReceipts+=("com.jetbrains.pycharm")
      appProcesses+=("pycharm")
      appFiles+=("/Applications/PyCharm.app")
      appFiles+=("<<Users>>/Library/Application Support/JetBrains/PyCharm2024.2")
      appFiles+=("<<Users>>/Library/Caches/JetBrains/PyCharm2024.2")
      appFiles+=("<<Users>>/Library/Logs/JetBrains/PyCharm2024.2")
      appFiles+=("<<Users>>/Library/Preferences/com.jetbrains.pycharm.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.jetbrains.pycharm.savedState")
      ;;
keynote)
      appTitle="Keynote"
      appProcesses+=("Keynote")
      appFiles+=("/Applications/Keynote.app")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.iWork.Keynote")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.iWork.Keynote.KeynoteNotificationServiceExtension")
      appFiles+=("<<Users>>/Library/Caches/com.apple.helpd/Generated/com.apple.iWork.Keynote.remote.help*14.3")
      appFiles+=("<<Users>>/Library/Containers/com.apple.iWork.Keynote")
      appFiles+=("<<Users>>/Library/Containers/com.apple.iWork.Keynote.KeynoteNotificationServiceExtension")
      appFiles+=("<<Users>>/Library/Group Containers/74J34U3R6X.com.apple.iWork")
      appFiles+=("<<Users>>/Library/Saved Application State/com.apple.iWork.Keynote.savedState")
      ;;
keyshot11)
      appTitle="KeyShot11"      
      appProcesses+=("KeyShot" "KeyShot11" "keyshot_daemon" "keyshot")
      appFiles+=("/Applications/KeyShot11.app")
      appFiles+=("/Applications/KeyShot11AuthHandler.app")
      appFiles+=("/Applications/KeyShotCloudHandler.app")
      appFiles+=("/Library/Application Support/KeyShot11")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.Analytics.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.Crash Reporter.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.luxion.keyshot.savedState")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.KeyShot 11.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.Keyshot Updater.plist")
      ;;
keyshot12)
      appTitle="KeyShot12"      
      appProcesses+=("KeyShot" "KeyShot12" "keyshot_daemon" "keyshot")
      appFiles+=("/Applications/KeyShot12.app")
      appFiles+=("/Applications/KeyShot12AuthHandler.app")
      appFiles+=("/Applications/KeyShotCloudHandler.app")
      appFiles+=("/Library/Application Support/KeyShot12")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.Analytics.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.Crash Reporter.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.KeyShot 12.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.luxion.Keyshot Updater.plist")
      ;;
lanschoolstudent)
      appTitle="LanSchool Student"
      appProcesses+=("student")
      appLaunchAgents+=("/Library/LaunchAgents/com.lanschool.student.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.lanschool.StudentHelper.plist")
      appFiles+=("/Applications/student.app")
      appFiles+=("/Library/Preferences/com.lanschool.student.config.plist")
      appFiles+=("/Library/Preferences/com.lanschool.student.settings.plist")
      appFiles+=("/Library/PrivilegedHelperTools/com.lanschool.StudentHelper")
      appFiles+=("<<Users>>/Library/Caches/com.lanschool.student")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.lanschool.student")
      appFiles+=("<<Users>>/Library/Preferences/com.lanschool.student.plist")
      appReceipts+=("com.lanschool.student.setup.pkg")
      ;;
linearmouse)
      # credit: pmex
      appTitle="LinearMouse"
      appProcesses+=("LinearMouse")
      appFiles+=("/Applications/LinearMouse.app")
      appFiles+=("<<Users>>/Library/Preferences/com.lujjjh.LinearMouse.plist")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.lujjjh.LinearMouse")
      ;;
logioptionsplus)
      appTitle="Logi Options+"
      appFiles+=("/Applications/logioptionsplus.app")
      appFiles+=("/Users/Shared/logi")
      appFiles+=("/Users/Shared/LogiOptionsPlus")
      appFiles+=("<<Users>>/Library/Application Support/Logitech/LogiOptionsPlus")
      appFiles+=("<<Users>>/Library/Application Support/com.logitech.logiaipromptbuilder")
      appFiles+=("<<Users>>/Library/Application Support/LogiOptionsPlus")
      appFiles+=("<<Users>>/Library/Application Support/Logi")
      appFiles+=("/Library/Application Support/Logitech.localized/LogiOptionsPlus")
      appFiles+=("/Library/LaunchAgents/com.logi.optionsplus.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.logi.optionsplus.updater.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.logi.optionsplus.plist")
      appReceipts+=("com.logi.optionsplus.installer")
      ;;
mackeeper)
      appTitle="MacKeeper"
      appProcesses+=("MacKeeper" "MacKeeperAgent")
      appFiles+=("/Applications/MacKeeper.app")
      appFiles+=("/Library/PrivilegedHelperTools/com.mackeeper.MacKeeperPrivilegedHelper")
      appFiles+=("<<Users>>/Library/Application Scripts/com.mackeeper.MacKeeperAgent.MacKeeperAntiTracking")
      appFiles+=("<<Users>>/Library/Application Scripts/com.mackeeper.MacKeeperAgent.MacKeeperStopAd")
      appFiles+=("<<Users>>/Library/Application Scripts/com.mackeeper.MacKeeperAgent.MacKeeperStopAdSecond")
      appFiles+=("<<Users>>/Library/Application Support/com.mackeeper.MacKeeper-Info")
      appFiles+=("<<Users>>/Library/Application Support/com.mackeeper.MacKeeper")
      appFiles+=("<<Users>>/Library/Application Support/com.mackeeper.MacKeeperAgent")
      appFiles+=("<<Users>>/Library/Application Support/MacKeeper")
      appFiles+=("<<Users>>/Library/Caches/com.mackeeper.MacKeeper-Info")
      appFiles+=("<<Users>>/Library/Caches/com.mackeeper.MacKeeper")
      appFiles+=("<<Users>>/Library/Caches/com.mackeeper.MacKeeperAgent")
      appFiles+=("<<Users>>/Library/Containers/com.mackeeper.MacKeeperAgent.MacKeeperAntiTracking")
      appFiles+=("<<Users>>/Library/Containers/com.mackeeper.MacKeeperAgent.MacKeeperAntiTrackinglcon")
      appFiles+=("<<Users>>/Library/Containers/com.mackeeper.MacKeeperAgent.MacKeeperStopAd")
      appFiles+=("<<Users>>/Library/Containers/com.mackeeper.MacKeeperAgent.MacKeeperStopAdSecond")
      appFiles+=("<<Users>>/Library/Group Containers/64424ZBYX5.adBlocker")
      appFiles+=("<<Users>>/Library/Group Containers/64424ZBYX5.trackingBlocker")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.mackeeper.MacKeeper-Info")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.mackeeper.MacKeeper.binarycookies")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.mackeeper.MacKeeper")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.mackeeper.MacKeeperAgent")
      appFiles+=("<<Users>>/Library/Logs/MacKeeper")
      appFiles+=("<<Users>>/Library/Preferences/com.mackeeper.MacKeeper.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.mackeeper.MacKeeperAgent.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.mackeeper.MacKeeper.savedState")
      appFiles+=("<<Users>>/Library/WebKit/com.mackeeper.MacKeeper")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.mackeeper.MacKeeper-Info.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.mackeeper.MacKeeper-Reminder.plist")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.mackeeper.MacKeeperAgent.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.mackeeper.MacKeeperPrivilegedHelper.plist")
      appReceipts+=("com.mackeeper.MacKeeper.pkg")
      ;;
mdmwatchdog)
      # credit: pmex
      appTitle="Addigy MDM Watchdog"
      appFiles+=("/usr/local/bin/mdm-watchdog")
      appFiles+=("/Library/Application Support/mdm-watchdog")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.addigy.mdm-watchdog.plist")
      appReceipts+=("com.addigy.mdm-watchdog")      
     ;;
mendeleydesktop)
      appTitle="Mendeley Desktop"
      appProcesses+=("Mendeley Desktop")
      appFiles+=("/Applications/Mendeley Desktop.app")
      appFiles+=("<<Users>>/Library/Application Support/Mendeley Desktop")
      appFiles+=("<<Users>>/Library/Preferences/com.mendeley.Mendeley Desktop.plist")
      ;;
mendeleyreferencemanager)
      appTitle="Mendeley Reference Manager"
      appProcesses+=("Mendeley Reference Manager")
      appFiles+=("/Applications/Mendeley Reference Manager.app")
      appFiles+=("<<Users>>/Library/Application Support/Mendeley Reference Manager")
      appFiles+=("<<Users>>/Library/Logs/Mendeley Reference Manager")
      appFiles+=("<<Users>>/Library/Preferences/com.elsevier.mendeley.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.elsevier.mendeley.savedState")
      ;;
microsoftautoupdate)
      appTitle="Microsoft AutoUpdate"
      appProcesses+=("Microsoft AutoUpdate")
      appFiles+=("/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app")
      appFiles+=("/Library/Application Support/Microsoft/MAU2.0")
      appFiles+=("/Library/Caches/com.microsoft.autoupdate.fba")
      appFiles+=("/Library/Preferences/com.microsoft.autoupdate2.plist")
      appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.errorreporting")
      appFiles+=("<<Users>>/Library/Caches/com.microsoft.autoupdate.fba")
      appFiles+=("<<Users>>/Library/Caches/com.microsoft.autoupdate2")
      appFiles+=("<<Users>>/Library/Containers/com.microsoft.errorreporting")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.ms")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.autoupdate2")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.autoupdate.fba.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.autoupdate2.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.microsoft.update.agent.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist")
      ;;
microsoftdefender)
      appTitle="Microsoft Defender"
      appProcesses+=("wdav" "Microsoft Defender")
      appFiles+=("/Applications/Microsoft Defender.app")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.wdav.mainux.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.wdav.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.wdav.tray.plist")
      appFiles+=("/Library/Preferences/com.microsoft.wdav.tray.plist")
      appFiles+=("/Library/Application Support/Microsoft/Defender")
      appFiles+=("/Library/Application Support/Microsoft/DLP")
      appFiles+=("<<Users>>/Library/Application Support/com.microsoft.wdav.tray")
      appFiles+=("<<Users>>/Library/Application Support/com.microsoft.wdav.mainux")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.com.microsoft.wdav")
      appLaunchAgents+=("/Library/LaunchAgents/com.microsoft.wdav.tray.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.fresno.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.fresno.uninstall.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.dlp.install_monitor.plist")
      ;;
microsoftedge)
      appTitle="Microsoft Edge"
      appFiles+=("/Applications/Microsoft Edge.app")
      appFiles+=("<<Users>>/Library/Application Support/Microsoft Edge")
      appFiles+=("<<Users>>/Library/Caches/Microsoft Edge")
      appFiles+=("<<Users>>/Library/Saved Application State/com.microsoft.edgemac.savedState")
      appFiles+=("<<Users>>/Library/WebKit/com.microsoft.edgemac")
      appFiles+=("<<Users>>/Library/Microsoft/EdgeUpdater")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.edgemac.plist")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.edgemac")
      appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.edgemac.wdgExtension")
      appFiles+=("<<Users>>/Library/Containers/com.microsoft.edgemac.wdgExtension")
      appFiles+=("/Library/Microsoft/Edge")
      appFiles+=("<<Users>>/Library/Application Support/Microsoft/EdgeUpdater")
      appFiles+=("/Library/Application Support/Microsoft/EdgeUpdater")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.microsoft.EdgeUpdater.update.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.EdgeUpdater.wake.system.plist")
      postflightCommand+=("rm /Users/$loggedInUser/Library/LaunchAgents/com.microsoft.EdgeUpdater.*")
      ;;
microsoftonedrive)
      appTitle="OneDrive"
      appFiles+=("/Applications/OneDrive.app")
      appFiles+=("/Library/Logs/Microsoft/OneDrive")
      appFiles+=("<<Users>>/Library Application Scripts com.microsoft.OneDrive.FileProvider")
      appFiles+=("<<Users>>/Library Application Support/com.microsoft.OneDrive")
      appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.OneDrive-mac.FileProvider")
      appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.OneDrive-mac.FinderSync")
      appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.OneDrive.FileProvider")
      appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.OneDrive.FinderSync")
      appFiles+=("<<Users>>/Library/Application Support/com.microsoft.OneDrive")
      appFiles+=("<<Users>>/Library/Application Support/OneDrive")
      appFiles+=("<<Users>>/Library/Caches/com.microsoft.OneDrive") 
      appFiles+=("<<Users>>/Library/Caches/com.microsoft.OneDriveStandaloneUpdater")
      appFiles+=("<<Users>>/Library/Caches/com.microsoft.OneDriveUpdater")
      appFiles+=("<<Users>>/Library/Caches/OneDrive")
      appFiles+=("<<Users>>/Library/Containers/com.microsoft.OneDrive.FileProvider") 
      appFiles+=("<<Users>>/Library/Containers/OneDrive Finder Integration")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.OfficeOneDriveSyncIntegration")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.OneDriveStandaloneSuite")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.OneDriveSyncClientSuite")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.OneDrive.binarycookies")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.OneDrive") 
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.OneDriveStandaloneUpdater.binarycookies")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.OneDriveStandaloneUpdater")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.OneDriveUpdater.binarycookies")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.OneDriveUpdater")
      appFiles+=("<<Users>>/Library/Logs/OneDrive")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.OneDrive.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.OneDriveStandaloneUpdater.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.OneDriveUpdater.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.SharePoint-mac.plist")
      appFiles+=("<<Users>>/Library/Preferences/UBF8T346G9.OfficeOneDriveSyncIntegration.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.microsoft.OneDrive")
      appReceipts+=("com.microsoft.OneDrive-mac")
      appLaunchAgents+=("/Library/LaunchAgents/com.microsoft.OneDriveStandaloneUpdater.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.microsoft.SyncReporter.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.OneDriveStandaloneUpdaterDaemon.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.OneDriveUpdaterDaemon.plist")
      ;;
microsoftremotedesktop)
      appTitle="Microsoft Remote Desktop"
      appProcesses+=("Microsoft Remote Desktop")
      appFiles+=("/Applications/Microsoft Remote Desktop.app")
      appFiles+=("<<Users>>/Library/Containers/com.microsoft.rdc.macos")
      appFiles+=("<<Users>>/Library/Containers/com.microsoft.rdc.macos.qlx")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.com.microsoft.rdc")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.com.microsoft.oneauth")
      appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.rdc.macos.qlx")
      appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.rdc.macos")
      ;;
microsoftteamsclassic)
      appTitle="Microsoft Teams classic"
      appProcesses+=("MSTeams")
      appFiles+=("/Applications/Microsoft Teams classic.app")
      appFiles+=("/Applications/Microsoft Teams.app")
      appFiles+=("<<Users>>/Library/WebKit/com.microsoft.teams")
      appFiles+=("<<Users>>/Library/Saved Application State/com.microsoft.teams.savedState")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.teams.plist ")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.teams.binarycookies")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.teams")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.com.microsoft.teams")
      appFiles+=("<<Users>>/Library/Caches/com.microsoft.teams")
      appFiles+=("/Library/Preferences/com.microsoft.teams.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.teams.TeamsUpdaterDaemon.plist")
      preflightCommand+=("killall 'Teams'")
      ;;
microsoftword)
# Needs more testing
      appTitle="Microsoft Word"
      appFiles+=("/Applications/Microsoft Word.app")
      appFiles+=("/Library/Preferences/com.microsoft.Word.plist")
      appFiles+=("/Library/Managed Preferences/com.microsoft.Word.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.Word.plist")
      appFiles+=("<<Users>>/Library/Containers/com.microsoft.Word")
      appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.Word")
      appFiles+=("/Applications/.Microsoft Word.app.installBackup")
      appFiles+=("/Library/Application Support/Microsoft/Office365/User Content.localized/Startup.localized/Word")
      appFiles+=("/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.dot")
      appFiles+=("/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.dotx")
      appFiles+=("/Library/Application Support/Microsoft/Office365/User Content.localized/Templates.localized/*.dotm")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Startup.localized/Word")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.dot")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.dotx")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/User Content.localized/Templates.localized/*.dotm")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/mip_policy")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/FontCache")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/ComRPC32")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/TemporaryItems")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/Microsoft Office ACL*")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.Office/MicrosoftRegistrationDB.reg")
      ;;
mindmanager)
      appTitle="MindManager"
      appProcesses+=("MindManager")
      appFiles+=("/Applications/MindManager.app")
      appFiles+=("<<Users>>/Library/Application Support/MindManager")
      appFiles+=("<<Users>>/Library/Preferences/com.mindjet.mindmanager.22.plist")
      appFiles+=("<<Users>>/Library/Caches/com.mindjet.mindmanager.22")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.mindjet.mindmanager.22.binarycookies")
      appFiles+=("<<Users>>/Library/Saved Application State/com.mindjet.mindmanager.22.savedState")
      appFiles+=("<<Users>>/Library/WebKit/com.mindjet.mindmanager.22")
      appFiles+=("<<Users>>/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.mindjet.mindmanager.22.sfl2")
      ;;
miro)
      appTitle="Miro"
      appProcesses+=("Miro")
      appFiles+=("/Applications/Miro.app")
      appFiles+=("<<Users>>/Library/Caches/com.electron.realtimeboard")
      appFiles+=("<<Users>>/Library/Caches/com.electron.realtimeboard.ShipIt")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.electron.realtimeboard")
      appFiles+=("<<Users>>/Library/Preferences/com.electron.realtimeboard.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.electron.realtimeboard.savedState")
      ;;
mist)
      appTitle="Mist"      
      appProcesses+=("Mist")
      appFiles+=("/Applications/Mist.app")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.ninxsoft.mist.helper.plist")
      appFiles+=("/Library/PrivilegedHelperTools/com.ninxsoft.mist.helper")
      appFiles+=("<<Users>>/Library/Caches/com.ninxsoft.mist")
      appFiles+=("<<Users>>/Library/Caches/mist")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.ninxsoft.mist")
      appFiles+=("<<Users>>/Library/Preferences/com.ninxsoft.mist.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.ninxsoft.mist")
      appReceipts+=("com.ninxsoft.pkg.mist")
      ;;
monitorcontrol)
      appTitle="MonitorControl"
      appProcesses+=("MonitorControl")
      appFiles+=("/Applications/MonitorControl.app")
      appFiles+=("<<Users>>/Library/Application Scripts/app.monitorcontrol.MonitorControlHelper")
      appFiles+=("<<Users>>/Library/Containers/app.monitorcontrol.MonitorControlHelper")
      appFiles+=("<<Users>>/Library/HTTPStorages/app.monitorcontrol.MonitorControl")
      appFiles+=("<<Users>>/Library/Preferences/app.monitorcontrol.MonitorControl.plist")
      ;;
munki)
      appTitle="Managed Software Center"
      appProcesses+=("Managed Software Center")
      appFiles+=("/Applications/Managed Software Center.app")
      appFiles+=("/private/etc/paths.d/munki")
      appFiles+=("/usr/local/munki")
      appFiles+=("/Library/Managed Installs")
      appFiles+=("/Library/Preferences/ManagedInstalls.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.googlecode.munki.appusaged.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.googlecode.munki.authrestartd.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.googlecode.munki.logouthelper.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.googlecode.munki.managedsoftwareupdate-check.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.googlecode.munki.managedsoftwareupdate-install.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.googlecode.munki.managedsoftwareupdate-manualcheck.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.googlecode.munki.app_usage_monitor.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.googlecode.munki.ManagedSoftwareCenter.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.googlecode.munki.managedsoftwareupdate-loginwindow.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.googlecode.munki.munki-notifier.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.googlecode.munki.MunkiStatus.plist")
      appReceipts+=("com.googlecode.munki.admin")
      appReceipts+=("com.googlecode.munki.app")
      appReceipts+=("com.googlecode.munki.core")     
      appReceipts+=("com.googlecode.munki.launchd")
      appReceipts+=("com.googlecode.munki.app_usage")     
      appReceipts+=("com.googlecode.munki.python")
      ;;
mysqlworkbench)
      appTitle="MySQLWorkbench"
      appProcesses+=("MySQLWorkbench")
      appFiles+=("/Applications/MySQLWorkbench.app")
      appFiles+=("<<Users>>/Library/Preferences/com.oracle.workbench.MySQLWorkbench.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.oracle.workbench.MySQLWorkbench.savedState")
      # unsure what to do with the Application Support folder because it contains the connections file...
      # appFiles+=("<<Users>>/Library/Application Support/MySQL") 
      ;;
nomad)
      appTitle="NoMAD"
      appProcesses+=("NoMAD")
      appFiles+=("/Applications/NoMAD.app")
      appLaunchAgents+=("/Library/LaunchAgents/com.trusourcelabs.NoMAD.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.trusourcelabs.NoMAD.plist")
      ;;
notion)
      appTitle="Notion"      
      appProcesses+=("Notion")
      appFiles+=("/Applications/Notion.app")
      appFiles+=("<<Users>>/Library/Application Support/Notion")
      appFiles+=("<<Users>>/Library/Application Support/Notion Calendar")
      appFiles+=("<<Users>>/Library/Caches/notion.id")
      appFiles+=("<<Users>>/Library/Caches/notion.id.ShipIt")
      appFiles+=("<<Users>>/Library/HTTPStorages/notion.id")
      appFiles+=("<<Users>>/Library/Logs/Notion")
      appFiles+=("<<Users>>/Library/Preferences/notion.id.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/notion.id.savedState")
      appReceipts+=("notion.id.arm64")
      appReceipts+=("notion.id")
      appReceipts+=("notion.id.x64")
      ;;
nudge)
      appTitle="Nudge"
      appProcesses+=("Nudge")
      appFiles+=("/Applications/Utilities/Nudge.app")
      appFiles+=("<<Users>>/Library/Preferences/com.github.macadmins.Nudge.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.github.macadmins.Nudge.plist")
      ;;
numbers)
      appTitle="Numbers"
      appProcesses+=("Numbers")
      appFiles+=("//Applications/Numbers.app")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.iWork.Numbers")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.iWork.Numbers.NumbersNotificationServiceExtension")
      appFiles+=("<<Users>>/Library/Caches/com.apple.helpd/Generated/com.apple.iWork.Numbers.remote.help*14.3")
      appFiles+=("<<Users>>/Library/Containers/com.apple.iWork.Numbers")
      appFiles+=("<<Users>>/Library/Containers/com.apple.iWork.Numbers.NumbersNotificationServiceExtension")
      ;;
obs)
      appTitle="OBS"
      appProcesses+=("OBS" "OBS Studio")
      appFiles+=("/Applications/OBS.app")
      appFiles+=("<<Users>>/Library/Preferences/com.obsproject.obs-studio.plist")
      appFiles+=("<<Users>>/Library/Application Support/obs-studio")
      appFiles+=("<<Users>>/Library/Saved Application State/com.obsproject.obs-studio.savedState")
      ;;
oktaverify)
      appTitle="Okta Verify"
      appProcesses+=("Okta Verify")
      appFiles+=("/Applications/Okta Verify.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/B7F62B65BN.group.okta.macverify.shared")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/B7F62B65BN.group.okta.macverify.shared")
      ;;
omnissahorizonclient)
      appTitle="Omnissa Horizon Client"
      appFiles+=("/Applications/Omnissa Horizon Client.app")
      appFiles+=("/Library/Preferences/com.omnissa.horizon.client.mac.plist")
      appFiles+=("<<Users>>/Library/Caches/com.omnissa.horizon.client.mac")
      appFiles+=("<<Users>>/Library/Preferences/com.omnissa.horizon.keyboard.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.omnissa.horizon.client.mac.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.omnissa.horizon.client.mac")
      appFiles+=("<<Users>>/Library/Application Support/Omnissa Horizon Client")
      ;;
openvpnconnect)
      appTitle="OpenVPN Connect"
      appProcesses+=("OpenVPN Connect" "OpenVPNConnect")
      appFiles+=("/Applications/OpenVPN/OpenVPN Connect.app")
      appFiles+=("/Applications/OpenVPN")
      appFiles+=("<<Users>>/Library/Preferences/net.openvpn.OpenVPNConnect.plist")
      appFiles+=("<<Users>>/Library/Application Support/OpenVPN")
      appFiles+=("/Library/Application Support/OpenVPN")
      appFiles+=("/Library/Frameworks/OpenVPN.framework")
      appLaunchDaemons+=("/Library/LaunchDaemons/net.openvpn.client.plist")
      preflightCommand+=("/Applications/OpenVPN/Uninstall OpenVPN Connect.app/Contents/Resources/remove.sh")
      appReceipts+=("net.openvpn.connect")
      ;;
openvpnconnect3)
      appTitle="OpenVPN Connect"
      appProcesses+=("OpenVPN Connect" "OpenVPN Connect Helper" "OpenVPNConnect")
      appFiles+=("/Applications/OpenVPN Connect/OpenVPN Connect.app")
      appFiles+=("/Applications/OpenVPN Connect")
      appFiles+=("/Applications/OpenVPN Connect.app")
      appFiles+=("<<Users>>/Library/Application Support/OpenVPN Connect")
      appFiles+=("<<Users>>/Library/Preferences/org.openvpn.client.app.plist")
      appFiles+=("/Library/Frameworks/OpenVPNConnect.framework")
      appFiles+=("/Library/Frameworks/OVPNHelper.framework")
      appLaunchDaemons+=("/Library/LaunchDaemons/org.openvpn.client.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/org.openvpn.helper.plist")
      preflightCommand+=("/Applications/OpenVPN/Uninstall OpenVPN Connect.app/Contents/Resources/remove.sh")
      appReceipts+=("org.openvpn.client.pkg")
      appReceipts+=("org.openvpn.client_framework.pkg")
      appReceipts+=("org.openvpn.client_launch.pkg")
      appReceipts+=("org.openvpn.client_uninstall.pkg")
      ;;
opera)
      appTitle="Opera"
      appProcesses+=("Opera")
      appFiles+=("/Applications/Opera.app")
      appFiles+=("<<Users>>/Library/Caches/com.operasoftware.Opera")
      appFiles+=("<<Users>>/Library/Preferences/com.operasoftware.Opera.plist")
      appFiles+=("<<Users>>/Library/Application Support/com.operasoftware.Opera")
      ;;
pages)
      appTitle="Pages"
      appProcesses+=("Pages")
      appFiles+=("/Applications/Pages.app")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.iWork.Pages")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.iWork.Pages.PagesNotificationServiceExtension")
      appFiles+=("<<Users>>/Library/Caches/com.apple.helpd/Generated/com.apple.iork.Pages.remote.help*14.3")
      appFiles+=("<<Users>>/Library/Containers/com.apple.iWork.Pages")
      appFiles+=("<<Users>>/Library/Containers/com.apple.iWork.Pages.PagesNotificationServiceExtension")
      ;;
parallelsdesktop)
      appTitle="Parallels Desktop"
      appProcesses+=("Parallels Desktop")
      appProcesses+=("prl_client_app")
      appProcesses+=("prl_naptd")
      appProcesses+=("prl_disp_service")
      appProcesses+=("watchdog")
      appFiles+=("/Applications/Parallels Desktop.app")
      appFiles+=("/Library/Parallels/Parallels Desktop")
      appFiles+=("/Library/Preferences/Parallels")
      appFiles+=("<<Users>>/Library/Application Scripts/com.parallels.desktop.console.OpenInIE")
      appFiles+=("<<Users>>/Library/Application Scripts/com.parallels.desktop.console.ParallelsMail")
      appFiles+=("<<Users>>/Library/Caches/com.apple.helpd/Generated/com.parallels.desktop.console.help*18.1.1")
      appFiles+=("<<Users>>/Library/Caches/com.parallels.desktop.console")
      appFiles+=("<<Users>>/Library/Containers/com.parallels.desktop.console.OpeninIE")
      appFiles+=("<<Users>>/Library/Containers/com.parallels.desktop.console.ParallelsMail")
      appFiles+=("<<Users>>/Library/Preferences/com.parallels.Parallels Desktop Events.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.parallels.Parallels Desktop Statistics.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.parallels.Parallels Desktop.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.parallels.desktop.console.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.parallels.macvm.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.parallels.desktop.console.savedState")
      appFiles+=("<<Users>>/Library/WebKit/com.parallels.desktop.console")
      preflightCommand+=("kill $(ps aux | grep 'Parallels Desktop.app' | grep watchdog | awk '{print $2}')")
      ;;
parallelsrasclient)
	appTitle="Parallels Client"      
	appProcesses+=("Parallels Client")
	appFiles+=("/Applications/Parallels Client.app")
	;;
postman)
      appTitle="Postman"
      appProcesses+=("Postman")
      appFiles+=("/Applications/Postman.app")
      appFiles+=("<<Users>>/Library/Application Support/Postman")
      appFiles+=("<<Users>>/Library/Preferences/com.postmanlabs.mac.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.postmanlabs.mac.savedState")
      ;;
powermonitor)
      appTitle="Power Monitor"
      appProcesses+=("Power Monitor")
      appFiles+=("/Applications/Power Monitor.app")
      appFiles+=("/Library/LaunchDaemons/corp.sap.PowerMonitorDaemon.plist")
      appFiles+=("/Users/Shared/Power Monitor")
      appFiles+=("<<Users>>/Library/Application Scripts/corp.sap.PowerMonitor")
      appFiles+=("<<Users>>/Library/Containers/corp.sap.PowerMonitor")
      appReceipts+=("corp.sap.PowerMonitor.pkg")
      ;;
preform)
      appTitle="PreForm"      
      appProcesses+=("PreForm")
      appFiles+=("/Applications/PreForm.app")
      appFiles+=("<<Users>>/Library/Caches/com.formlabs.PreForm")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.formlabs.PreForm")
      appFiles+=("<<Users>>/Library/Preferences/com.formlabs.PreForm.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.formlabs.PreForm.savedState")
      appFiles+=("<<Users>>/Library/WebKit/com.formlabs.PreForm")
      appReceipts+=("com.formlabs.PreForm")
      ;;
privileges)
      appTitle="Privileges"
      appFiles+=("/Applications/Privileges.app")
      appFiles+=("/Library/PrivilegedHelperTools/corp.sap.privileges.helper")
      appFiles+=("<<Users>>/Library/Containers/corp.sap.privileges")
      appFiles+=("<<Users>>/Library/Application Scripts/corp.sap.privileges")
      appLaunchDaemons+=("/Library/LaunchDaemons/corp.sap.privileges.helper.plist")
      appLaunchAgents+=("/Library/LaunchAgents/corp.sap.privileges.plist")
      ;;
privilegesdemoter)
      appTitle="Privileges Demoter"
      appFiles+=("/private/etc/newsyslog.d/blog.mostlymac.PrivilegesDemoter.conf")
      appFiles+=("/usr/local/mostlymac/")
      appLaunchDaemons+=("/Library/LaunchDaemons/blog.mostlymac.privileges.check.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/blog.mostlymac.privileges.demote.plist")
      ;;
proxyman)
      appTitle="Proxyman"
      appProcesses+=("Proxyman")
      appFiles+=("/Applications/Proxyman.app")
      appFiles+=("<<Users>>/Library/Preferences/com.proxyman.iconappmanager.userdefaults.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.proxyman.NSProxy.plist")
      appFiles+=("<<Users>>/Library/Application Support/com.proxyman.NSProxy")
      appFiles+=("<<Users>>/Library/Caches/Proxyman")
      appFiles+=("<<Users>>/Library/Caches/com.proxyman.NSProxy")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.proxyman.NSProxy")
      appFiles+=("<<Users>>/Library/Saved Application State/com.proxyman.NSProxy.savedState")
      appFiles+=("<<Users>>/Library/WebKit/com.proxyman.NSProxy")
      appFiles+=("/Library/LaunchDaemons/com.proxyman.NSProxy.HelperTool.plist")
      appFiles+=("/Library/PrivilegedHelperTools/com.proxyman.NSProxy.HelperTool")
      ;;
pycharmce)
      appTitle="PyCharm CE"
      appProcesses+=("pycharm")
      appFiles+=("/Applications/PyCharm CE.app")
      appReceipts+=("com.jetbrains.pycharm.ce")     
      appFiles+=("<<Users>>/Library/Preferences/com.jetbrains.pycharm.ce.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.jetbrains.pycharm.ce.savedState")
      ;;
r)
      appTitle="R"
      appProcesses+=("R")
      appFiles+=("/Applications/R.app")
      appFiles+=("/Library/Frameworks/R.framework")
      appFiles+=("/opt/R")
      appFiles+=("<<Users>>/Library/Preferences/org.R-project.R.plist")
      ;;
redshift)
      appTitle="Redshift"
      appProcesses+=( "Maya" "Cinema 4D" )
      appFiles+=("/Applications/redshift")
      appFiles+=("/Applications/Cinema 4D R21/plugins/Redshift")
      appFiles+=("/Applications/Cinema 4D R22/plugins/Redshift")
      appFiles+=("/Applications/Cinema 4D R23/plugins/Redshift")
      appFiles+=("/Applications/Cinema 4D R24/plugins/Redshift")
      appFiles+=("/Applications/Cinema 4D R25/plugins/Redshift")
      appFiles+=("/Applications/Cinema 4D R26/plugins/Redshift")
      appFiles+=("/Applications/Cinema 4D 2023/plugins/Redshift")
      appFiles+=("/Applications/Cinema 4D 2024/plugins/Redshift")
      appFiles+=("/Applications/Autodesk/maya2018/Maya.app/Contents/modules/redshift4maya.mod")
      appFiles+=("/Applications/Autodesk/maya2019/Maya.app/Contents/modules/redshift4maya.mod")
      appFiles+=("/Applications/Autodesk/maya2020/Maya.app/Contents/modules/redshift4maya.mod")
      appFiles+=("/Applications/Autodesk/maya2022/Maya.app/Contents/modules/redshift4maya.mod")
      appFiles+=("/Applications/Autodesk/maya2023/Maya.app/Contents/modules/redshift4maya.mod")
      appFiles+=("/Applications/Autodesk/maya2024/Maya.app/Contents/modules/redshift4maya.mod")
      appFiles+=("<<Users>>/redshift")
      ;;
remarkable)
      appTitle="reMarkable"
      appProcesses+=("reMarkable")
      appFiles+=("/Applications/reMarkable.app")
      appFiles+=("<<Users>>/Library/Preferences/com.remarkable.desktop.plist")
      appFiles+=("<<Users>>/Library/Application Support/remarkable")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.remarkable.desktop")
      appFiles+=("<<Users>>/Library/Caches/remarkable")
      ;;
rightfont)
      appTitle="RightFont"
      appProcesses+=("RightFont")
      appFiles+=("/Applications/RightFont.app/")
      appFiles+=("<<Users>>/Library/Application Scripts/com.rightfontapp.RightFontHelper")
      appFiles+=("<<Users>>/Library/Application Support/CrashReporter/RightFont_AB72377B-AF64-597F-817B-BCD24A8D6BC1.plist")
      appFiles+=("<<Users>>/Library/Application Support/com.rightfontapp.RightFont5")
      appFiles+=("<<Users>>/Library/Caches/com.rightfontapp.RightFont5")
      appFiles+=("<<Users>>/Library/Containers/com.rightfontapp.RightFontHelper")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.rightfontapp.RightFont5")
      appFiles+=("<<Users>>/Library/Logs/RightFont")
      appFiles+=("<<Users>>/Library/Preferences/com.rightfontapp.RightFont5.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.rightfontapp.RightFont5.savedState")
      appFiles+=("<<Users>>/Library/WebKit/com.rightfontapp.RightFont5")
      ;;
rodeconnect)
      appTitle="RODEConnect"
      appProcesses+=("RODE Connect")
      appProcesses+=("Core Audio Driver (RodeConnect.driver)")
      appFiles+=("/Applications/RODE Connect.app")
      appFiles+=("/Library/Audio/Plug-Ins/HAL/RodeConnect.driver")
      appFiles+=("/Library/Fonts/RODE Noto Sans CJK SC B.otf")
      appFiles+=("/Library/Fonts/RODE Noto Sans CJK SC R.otf")
      appFiles+=("/Library/Fonts/RODE Noto Sans Hindi B.ttf")
      appFiles+=("/Library/Fonts/RODE Noto Sans Hindi R.ttf")
      appFiles+=("<<Users>>/Library/Application Support/RØDE")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.rode.rodeconnect")
      appFiles+=("<<Users>>/Library/Caches/com.rode.rodeconnect")
      ;;
rstudio)
      appTitle="RStudio"
      appProcesses+=("RStudio")
      appFiles+=("/Applications/RStudio.app")
      appFiles+=("<<Users>>/Library/Application Support/RStudio")
      appFiles+=("<<Users>>/Library/Preferences/com.rstudio.desktop.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.rstudio.desktop.savedState")
      ;;
safeexambrowser)
      appTitle="Safe Exam Browser"
      appProcesses+=("Safe Exam Browser")
      appFiles+=("/Applications/Safe Exam Browser.app")
      appFiles+=("<<Users>>/Library/Caches/org.safeexambrowser.SafeExamBrowser")
      appFiles+=("<<Users>>/Library/Logs/Safe Exam Browser")
      appFiles+=("<<Users>>/Library/Preferences/org.safeexambrowser.SafeExamBrowser.plist")
      appFiles+=("<<Users>>/Library/WebKit/org.safeexambrowser.SafeExamBrowser")
      ;;
setupmanager)
      appTitle="Setup Manager"
      appProcesses+=("Setup Manager")
      appFiles+=("/Applications/Utilities/Setup Manager.app")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.jamf.setupmanager.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.setupmanager.loginwindow.plist")
      appFiles+=("/Library/Logs/Setup Manager.log")
      appFiles+=("<<Users>>/Library/Caches/com.jamf.setupmanager")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.jamf.setupmanager")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.jamf.setupmanager.binarycookies")
      # as Setup Manager runs at enrollment or at the login window it will store its files
      # in the root directory
      appFiles+=("/private/var/root/Library/Caches/com.jamf.setupmanager")
      appFiles+=("/private/var/root/Library/HTTPStorages/com.jamf.setupmanager")
      appFiles+=("/private/var/root/Library/HTTPStorages/com.jamf.setupmanager.binarycookies")
      appReceipts+=("com.jamf.setupmanager")
      ;;
shottr)
      appTitle="Shottr"
      appFiles+=("/Applications/Shottr.app")
      appFiles+=("<<Users>>/Library/Application Scripts/cc.ffitch.shottr")
      appFiles+=("<<Users>>/Library/Containers/cc.ffitch.shottr")
      ;;
shutterencoder)
      appTitle="Shutter Encoder"
      # the app process is a jre binary launched by sh, so it won't be found :-/
      appProcesses+=("Shutter Encoder")
      appFiles+=("/Applications/Shutter Encoder.app")
      ;;
silverlight)
      appTitle="Silverlight"
      appProcesses+=("SLLauncher")
      appFiles+=("/Library/Application Support/Microsoft/Silverlight/OutOfBrowser/SLLauncher.app")
      appFiles+=("/Library/Application Support/Microsoft/Silverlight")
      appFiles+=("/Library/Internet Plug-Ins/Silverlight.plugin")
      appFiles+=("/Applications/Microsoft Silverlight")
      appReceipts+=("com.microsoft.Silverlightinstaller")
      ;;
sketch)
      appTitle="Sketch"
      appFiles+=("/Applications/Sketch.app")
      appFiles+=("<<Users>>/Library/WebKit/com.bohemiancoding.sketch3")
      appFiles+=("<<Users>>/Library/Saved Application State/com.bohemiancoding.sketch3.savedState")
      appFiles+=("<<Users>>/Library/Preferences/com.bohemiancoding.sketch3.plist")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.bohemiancoding.sketch3") 
      appFiles+=("<<Users>>/Library/Containers/com.bohemiancoding.sketch3.QuickLook-Thumbnail")
      appFiles+=("<<Users>>/Library/Containers/com.bohemiancoding.sketch3.QuickLook-Preview")
      appFiles+=("<<Users>>/Library/Application Support/com.bohemiancoding.sketch3")
      appFiles+=("<<Users>>/Library/Caches/com.bohemiancoding.sketch3")
      appFiles+=("<<Users>>/Library/Application Scripts/com.bohemiancoding.sketch3.QuickLook-Thumbnail")
      appFiles+=("<<Users>>/Library/Application Scripts/com.bohemiancoding.sketch3.QuickLook-Preview")
      ;;
sketchup2024)
      appTitle="SketchUp"      
      appProcesses+=("SketchUp" "LayOut" "Style Builder" "SketchUp Helper")
      appFiles+=("/Applications/SketchUp 2024/SketchUp.app")
      appFiles+=("/Applications/SketchUp 2024")
      appFiles+=("<<Users>>/Library/Application Scripts/com.sketchup.LayOut.2024.LayOutThumbnailExtension")
      appFiles+=("<<Users>>/Library/Application Scripts/com.sketchup.SketchUp.2024.SketchUpThumbnailExtension")
      appFiles+=("<<Users>>/Library/Application Support/SketchUp 2024")
      appFiles+=("<<Users>>/Library/Caches/com.sketchup.LayOut.2024")
      appFiles+=("<<Users>>/Library/Caches/com.sketchup.SketchUp.2024")
      appFiles+=("<<Users>>/Library/Caches/com.sketchup.StyleBuilder.2024")
      appFiles+=("<<Users>>/Library/Containers/com.sketchup.LayOut.2024.LayOutThumbnailExtension")
      appFiles+=("<<Users>>/Library/Containers/com.sketchup.SketchUp.2024.SketchUpThumbnailExtension")
      appFiles+=("<<Users>>/Library/Preferences/com.sketchup.LayOut.2024.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.sketchup.SketchUp.2024.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.sketchup.StyleBuilder.2024.plist")
      appFiles+=("<<Users>>/Library/Preferences/Trimble.SketchUp-Helper.(Renderer).plist")
      appFiles+=("<<Users>>/LLibrary/Preferences/com.sketchup.StyleBuilder.2024.plist")
      postflightCommand+=("pkill 'SketchUp'")
      ;;
skype)
      appTitle="Skype"
      appFiles+=("/Applications/Skype.app")
      appFiles+=("<<Users>>/Library/Caches/com.skype.skype/")
      appFiles+=("<<Users>>/Library/Caches/com.skype.skype.ShipIt/")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.skype.skype")
      appFiles+=("<<Users>>/Library/Logs/Skype Helper (Renderer)")
      appFiles+=("<<Users>>/Library/Preferences/com.skype.skype.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.skype.skype.savedState")
      appFiles+=("<<Users>>/Library/Application Support/Microsoft/Skype for Desktop")
      ;;
slack)
      appTitle="Slack"
      appProcesses+=("Slack")
      appFiles+=("/Applications/Slack.app")
      appFiles+=("<<Users>>/Library/Application Support/Slack")
      appFiles+=("<<Users>>/Library/Preferences/com.tinyspeck.slackmacgap.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.tinyspeck.slackmacgap.savedState")
      appReceipts+=("com.tinyspeck.slackmacgap")
      ;;
sonoss2)
      # Keep label the same as the Installomator label	
      appTitle="Sonos"      
      appProcesses+=("Sonos")
      appFiles+=("/Applications/Sonos.app")
      appFiles+=("<<Users>>/Library/Caches/com.sonos.macController2")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.sonos.macController2")
      appFiles+=("<<Users>>/Library/Logs/Sonos")
      appFiles+=("<<Users>>/Library/Logs/Sonos Installer")
      appFiles+=("<<Users>>/Library/Preferences/com.sonos.macController2.plist")
      preflightCommand+=("kill -9 $(pgrep -f 'Sonos')")
      ;;
sourcetree)
      appTitle="Sourcetree"
      appFiles+=("/Applications/Sourcetree.app")
      appFiles+=("<<Users>>/Library/Application Support/sourcetree/")
      appFiles+=("<<Users>>/Library/Logs/sourcetree/")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.torusknot.SourceTreeNotMAS")
      appFiles+=("<<Users>>/Library/Preferences/com.torusknot.SourceTreeNotMAS.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.torusknot.SourceTreeNotMAS.savedState")
      ;;
spotify)
      appTitle="Spotify"
      appFiles+=("/Applications/Spotify.app")
      appFiles+=("<<Users>>/Applications/Spotify.app")
      appFiles+=("<<Users>>/Library/Application Support/Spotify/")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.spotify.client")
      appFiles+=("<<Users>>/Library/Preferences/com.spotify.client.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.spotify.client.savedState")
      appFiles+=("<<Users>>/Library/Caches/com.spotify.client")
      ;;
steam)
      appTitle="Steam"
      appFiles+=("/Applications/Steam.app")
      appLaunchAgents+=("<<Users>>/Library/LaunchAgents/com.valvesoftware.steamclean.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.valvesoftware.steam.savedState")      
      ;;
sublimetext)
      appTitle="Sublime Text"      
      appProcesses+=("Sublime Text" "sublime_text")
      appFiles+=("/Applications/Sublime Text.app")
      appFiles+=("<<Users>>/Library/Application Support/Sublime Text")
      appFiles+=("<<Users>>/Library/Caches/Sublime Text")
      appFiles+=("<<Users>>/Library/Caches/com.sublimetext.4")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.sublimetext.4")
      appFiles+=("<<Users>>/Library/Saved Application State/com.sublimetext.4.savedState")
      ;;
superman)
      appTitle="superman"
      appProcesses+=("support")
      appFiles+=("/Applications/Support.app")
      appFiles+=("/usr/local/bin/super")
      appFiles+=("/var/run/super.pid")
      appLaunchAgents+=("/Library/LaunchAgents/com.macjutsu.super.plist")
      ;;
supportapp)
      appTitle="Support app"
      appProcesses+=("Support")
      appFiles+=("/Applications/Support.app")
      appFiles+=("<<Users>>/Library/Application Scripts/nl.root3.support")
      appFiles+=("<<Users>>/Library/Containers/nl.root3.support")
      appFiles+=("<<Users>>/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/nl.root3.support.sfl2")
      appLaunchAgents+=("/Library/LaunchAgents/nl.root3.support.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/nl.root3.support.helper.plist")
      ;;
suspiciouspackage)
      appTitle="Suspicious Package"
      appProcesses+=("Suspicious Package")
      appFiles+=("/Applications/Suspicious Package.app")
      appFiles+=("<<Users>>/Library/Preferences/com.mothersruin.SuspiciousPackage.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.mothersruin.SuspiciousPackageApp.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.mothersruin.SuspiciousPackageApp.savedState")
      ;;
swiftdialog)
      appTitle="swiftDialog"
      appProcesses+=("dialog")
      appFiles+=("/Library/Application Support/Dialog")
      appFiles+=("/usr/local/bin/dialog")
      appReceipts+=("au.csiro.dialogcli")
      ;;
teamviewer)
      appTitle="TeamViewer"
      appProcesses+=("TeamViewer")
      appFiles+=("/Applications/TeamViewer.app")
      appFiles+=("/Library/Application Support/TeamViewer/")
      appFiles+=("/Library/PrivilegedHelperTools/com.teamviewer.Helper")
      appFiles+=("/Library/Preferences/com.teamviewer.teamviewer.preferences.plist")
      appFiles+=("<<Users>>/Library/Application Support/TeamViewer/")
      appFiles+=("<<Users>>/Library/Preferences/com.teamviewer.TeamViewer.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.teamviewer.teamviewer.preferences.Machine.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.teamviewer.teamviewer.preferences.plist")
      appFiles+=("<<Users>>/Library/Caches/TeamViewer/")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.teamviewer.TeamViewer")
      appFiles+=("<<Users>>/Library/WebKit/com.teamviewer.TeamViewer")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.teamviewer.Helper.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.teamviewer.teamviewer_service.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.teamviewer.teamviewer_desktop.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.teamviewer.teamviewer.plist")
      appReceipts+=("com.teamviewer.teamviewer")
      appReceipts+=("com.teamviewer.teamviewerPriviledgedHelper")
      appReceipts+=("com.teamviewer.remoteaudiodriver")     
      appReceipts+=("com.teamviewer.AuthorizationPlugin")
      ;;
textexpander)
      appTitle="TextExpander"
      appProcesses+=("TextExpander")
      appFiles+=("/Applications/TextExpander.app")    
      appFiles+=("<<Users>>/Library/Caches/com.smileonmymac.textexpander")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.smileonmymac.textexpander")
      appFiles+=("<<Users>>/Library/Preferences/com.smileonmymac.textexpander.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.smileonmymac.textexpander")
      appReceipts+=("com.smileonmymac.textexpander")      
      ;;
textwrangler)
      appTitle="TextWrangler"
      appProcesses+=("TextWrangler")
      appFiles+=("/Applications/TextWrangler.app")
      appFiles+=("<<Users>>/Library/Application Support/TextWrangler")
      appFiles+=("<<Users>>/Library/TextWrangler")
      appFiles+=("<<Users>>/Library/Preferences/com.barebones.textwrangler.plist")
      appFiles+=("<<Users>>/Library/Containers/com.barebones.textwrangler")
      appFiles+=("<<Users>>/Library/Application Scripts/com.barebones.textwrangler")
      appFiles+=("/usr/local/bin/edit")
      appFiles+=("/usr/local/bin/twdiff")
      appFiles+=("/usr/local/bin/twfind")
      ;;
theunarchiver)
      appTitle="The Unarchiver"
      appProcesses+=("The Unarchiver")
      appFiles+=("/Applications/The Unarchiver.app")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.macpaw.site.theunarchiver")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.macpaw.site.theunarchiver.binarycookies")
      appFiles+=("<<Users>>/Library/Preferences/com.macpaw.site.theunarchiver.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.macpaw.site.theunarchiver.savedState")
      appReceipts+=("cx.c3.theunarchiver")
      ;;
tinkertoolsystem8)
      appTitle="tinkertoolsystem8"
      appProcesses+=("TinkerTool System")
      appFiles+=("/Applications/TinkerTool System.app")
      appFiles+=("<<Users>>/Library/Preferences/com.bresink.system.tinkertoolsystem8.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.bresink.system.tinkertoolsystem8.savedState")
      ;;
transmission)
      appTitle="Transmission"
      appProcesses+=("Transmission")
      appFiles+=("/Applications/Transmission.app")
      appFiles+=("<<Users>>/Library/Application Support/Transmission")
      appFiles+=("<<Users>>/Library/Caches/org.m0k.transmission")
      appFiles+=("<<Users>>/Library/HTTPStorages/org.m0k.transmission")
      appFiles+=("<<Users>>/Library/Preferences/org.m0k.transmission.plist")
      ;;
ultimakercura)
      appTitle="Ultimaker Cura"
      appProcesses+=("Ultimaker Cura" "UltiMaker-Cura")
      appFiles+=("/Applications/Ultimaker Cura.app")
      appFiles+=("/Applications/Ultimaker-Cura.app")
      appFiles+=("/Applications/Ultimaker Cura.localized")
      appFiles+=("/Applications/Ultimaker Cura-1.localized")
      appReceipts+=("nl.ultimaker.cura")
      ;;
utm)
	appTitle="UTM"      
	appProcesses+=("UTM")
	appFiles+=("/Applications/UTM.app")
	appFiles+=("<<Users>>/Library/Saved Application State/com.utmapp.UTM.savedState")
	appFiles+=("<<Users>>/Library/Application Scripts/com.utmapp.UTM")
	printlog "IMPORTANT: We don't want to touch User data! Keeping the VM's intact..."
	printlog "IMPORTANT: Check label for extra info."
	# If you want to remove the VM's, they live here:
	# /Users/homefolder/Library/Containers/com.utmapp.UTM
	# /Users/homefolder/Library/Group Containers/WDNLXAD4W8.com.utmapp.UTM
	;;
virtualbuddy)
      appTitle="VirtualBuddy"      
      appProcesses+=("VirtualBuddy")
      appFiles+=("/Applications/VirtualBuddy.app")
      appFiles+=("<<Users>>/Library/Application Support/VirtualBuddy")
      appFiles+=("<<Users>>/Library/Caches/codes.rambo.VirtualBuddy")
      appFiles+=("<<Users>>/Library/HTTPStorages/codes.rambo.VirtualBuddy")
      appFiles+=("<<Users>>/Library/Preferences/codes.rambo.VirtualBuddy.plist")
      appFiles+=("<<Users>>/Library/WebKit/codes.rambo.VirtualBuddy")
      ;;
visualstudiocode)
      appTitle="Visual Studio Code"
      # appProcesses+=("Code") # Electron app...
      appFiles+=("/Applications/Visual Studio Code.app")
      appFiles+=("<<Users>>/Library/Application Support/Code")
      appFiles+=("<<Users>>/.vscode")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.VSCode.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.microsoft.VSCode.savedState")
      appFiles+=("<<Users>>/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.microsoft.vscode.sfl2")
      preflightCommand+=("kill -9 $(pgrep -f /Applications/Visual\ Studio\ Code.app/Contents/MacOS/Electron)")
      ;;
vlc)
      appTitle="VLC"
      appProcess+=("VLC")
      appFiles+=("/Applications/VLC.app")
      appFiles+=("<<Users>>/Library/Preferences/org.videolan.vlc")
      appFiles+=("<<Users>>/Library/Preferences/org.videolan.vlc.plist")
      appFiles+=("<<Users>>/Library/Application Support/org.videolan.vlc")
      appFiles+=("<<Users>>/Library/Caches/org.videolan.vlc")
      appFiles+=("<<Users>>/Library/HTTPStorages/org.videolan.vlc")
      appFiles+=("<<Users>>/Library/Saved Application State/org.videolan.vlc.savedState")
      ;;
vmwarefusion)
      appTitle="VMware Fusion"
      appProcesses+=("VMware Fusion")
      appFiles+=("/Applications/VMware Fusion.app")
      appFiles+=("/Library/Application Support/VMware/VMware Fusion")
      appFiles+=("/Library/Application Support/VMware/Usbarb.rules")
      appFiles+=("/Library/Application Support/VMware Fusion")
      appFiles+=("/Library/Preferences/VMware Fusion")
      appFiles+=("/private/etc/paths.d/com.vmware.fusion.public")
      appFiles+=("<<Users>>/Library/Application Support/VMware Fusion")
      appFiles+=("<<Users>>/Library/Caches/com.vmware.fusion")
      appFiles+=("<<Users>>/Library/Preferences/VMware Fusion")
      appFiles+=("<<Users>>/Library/Logs/VMware Fusion")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.fusion.LSSharedFileList.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.fusion.LSSharedFileList.plist.lockfile")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.fusion.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.fusion.plist.lockfile")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.fusionDaemon.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.fusionDaemon.plist.lockfile")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.fusionStartMenu.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.fusionStartMenu.plist.lockfile")
      ;;
vmwarehorizonclient)
      appTitle="VMware Horizon Client"
      appFiles+=("/Applications/VMware Horizon Client.app")
      appFiles+=("/Library/Preferences/com.vmware.horizon.plist")
      appFiles+=("<<Users>>/Library/Caches/com.vmware.horizon")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.horizon.keyboard.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.vmware.horizon.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.vmware.horizon")
      appFiles+=("<<Users>>/Library/Application Support/VMware Horizon View Client")
      ;;
wacomdrivers)
      appTitle="Wacom Center"
      appFiles+=("/Applications/Wacom Tablet.localized/Wacom Center.app")
      appFiles+=("/Applications/Wacom Tablet.localized")
      appFiles+=("/Library/Application Support/Tablet/")
      appFiles+=("/Library/Frameworks/WacomMultiTouch.framework")
      appFiles+=("/Library/PreferencePanes/WacomCenter.prefpane")
      appFiles+=("/Library/PreferencePanes/WacomTablet.prefpane")
      appFiles+=("/Library/Preferences/Tablet")
      appFiles+=("/Library/PrivilegedHelperTools/com.wacom.DataStoreMgr.app")
      appFiles+=("/Library/PrivilegedHelperTools/com.wacom.IOManager")
      appFiles+=("/Library/PrivilegedHelperTools/com.wacom.UpdateHelper")
      appFiles+=("<<Users>>/Library/Preferences/com.wacom.ProfessionalTablet.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.wacom.wacomtablet.prefs")
      appFiles+=("<<Users>>/Library/Preferences/com.wacom.wacomtouch.prefs")
      appFiles+=("<<Users>>/Library/Group Containers/EG27766DY7.com.wacom.WacomTabletDriver")
      appFiles+=("<<Users>>/Library/Group Containers/com.wacom.TabletDriver")
      appLaunchAgents+=("/Library/LaunchAgents/com.wacom.DataStoreMgr.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.wacom.IOManager.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.wacom.wacomtablet.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.wacom.UpdateHelper.plist")
     ;;
webex)
      appTitle="Webex"
      appProcesses+=("Webex")
      appFiles+=("/Applications/Webex.app")
      appFiles+=("<<Users>>/Library/Application Support/Cisco Spark/Webexteams_upgrades/Webex")
      appFiles+=("<<Users>>/Library/Application Support/Cisco Spark/Webexteams_upgrades_arm/Webex")
      appFiles+=("<<Users>>/Library/Caches/Cisco-Systems.Spark")
      appFiles+=("<<Users>>/Library/Preferences/Cisco-Systems.Spark.plist")
      appFiles+=("<<Users>>/Library/WebKit/Cisco-Systems.Spark")
      ;;
whatsapp)
      appTitle="WhatsApp"
      appFiles+=("/Applications/WhatsApp.app")
      appFiles+=("<<Users>>/Library/Application Support/WhatsApp")
      appFiles+=("<<Users>>/Library/Application Scripts/net.whatsapp.WhatsApp")
      appFiles+=("<<Users>>/Library/Caches/WhatsApp")
      appFiles+=("<<Users>>/Library/Caches/WhatsApp.ShipIt")
      appFiles+=("<<Users>>/Library/Containers/net.whatsapp.WhatsApp")
      appFiles+=("<<Users>>/Library/Saved Application State/WhatsApp.savedState")
      appFiles+=("<<Users>>/Library/Group Containers/group.net.whatsapp.WhatsApp.private")
      appFiles+=("<<Users>>/Library/Group Containers/group.com.facebook.family")
      appFiles+=("<<Users>>/Library/Group Containers/group.net.whatsapp.WhatsAppSMB.shared")
      appFiles+=("<<Users>>/Library/Group Containers/group.net.whatsapp.WhatsAppSMB.private")
      appFiles+=("<<Users>>/Library/Group Containers/group.net.whatsapp.family")
      appFiles+=("<<Users>>/Library/Preferences/WhatsApp.plist")
      ;;
windscribe)
      appTitle="Windscribe"
      appFiles+=("/Applications/Windscribe.app")
      appFiles+=("/Library/PrivilegedHelperTools/com.windscribe.helper.macos")
      appFiles+=("/Library/Logs/com.windscribe.helper.macos")
      appFiles+=("<<Users>>/Library/Application Scripts/com.windscribe.launcher.macos")
      appFiles+=("<<Users>>/Library/Application Support/Windscribe")
      appFiles+=("<<Users>>/Library/Containers/com.windscribe.launcher.macos")
      appFiles+=("<<Users>>/Library/Preferences/com.windscribe.Windscribe2.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.windscribe.gui.macos.savedState")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.windscribe.helper.macos.plist")
      ;;
wireguard)
      appTitle="WireGuard"
      appProcesses+=("WireGuard")
      appFiles+=("/Applications/WireGuard.app")
      appFiles+=("<<Users>>/Library/Application Scripts/com.wireguard.macos")
      appFiles+=("<<Users>>/Library/Application Scripts/com.wireguard.macos.network-extension")
      appFiles+=("<<Users>>/Library/Containers/com.wireguard.macos")
      appFiles+=("<<Users>>/Library/Group Containers/L82V4Y2P3C.group.com.wireguard.macos")
      ;;
xcode)
      appTitle="Xcode"
      appFiles+=("/Applications/Xcode.app")
      appFiles+=("/Library/Preferences/com.apple.dt.Xcode.plist")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.dt.DVTFeedbackReporting.DVTFeedbackReportingDiagnosticExtension")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.dt.DVTFeedbackReporting.XCCFeedbackReportingDiagnosticExtension")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.dt.DVTProvisioningProfileQuicklookExtension")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.dt.Instruments.InstrumentsShareExtension")
      appFiles+=("<<Users>>/Library/Application Scripts/com.apple.iphonesimulator.ShareExtension")
      appFiles+=("<<Users>>/Library/Application Support/Xcode")
      appFiles+=("<<Users>>/Library/Application Support/com.apple.dt.Xcode")
      appFiles+=("<<Users>>/Library/Caches/com.apple.dt.Xcode")
      appFiles+=("<<Users>>/Library/Caches/com.apple.dt.xcodebuild")
      appFiles+=("<<Users>>/Library/Containers/com.apple.dt.DVTFeedbackReporting.DVTFeedbackReportingDiagnosticExtension")
      appFiles+=("<<Users>>/Library/Containers/com.apple.dt.DVTFeedbackReporting.XCCFeedbackReportingDiagnosticExtension")
      appFiles+=("<<Users>>/Library/Containers/com.apple.dt.DVTProvisioningProfileQuicklookExtension")
      appFiles+=("<<Users>>/Library/Containers/com.apple.dt.Instruments.InstrumentsShareExtension")
      appFiles+=("<<Users>>/Library/Containers/com.apple.iphonesimulator.ShareExtension")
      appFiles+=("<<Users>>/Library/Developer/CoreSimulator")
      appFiles+=("<<Users>>/Library/Developer/Xcode")
      appFiles+=("<<Users>>/Library/Group Containers/59GAB85EFG.com.apple.dt.XcodeCloud")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.apple.dt.Xcode.binarycookies")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.apple.dt.Xcode.ITunesSoftwareService")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.apple.dt.Xcode")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.apple.dt.xcodebuild")
      appFiles+=("<<Users>>/Library/Preferences/com.apple.dt.SKAgent.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.apple.dt.Xcode.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.apple.dt.xcodebuild.plist")
      appFiles+=("<<Users>>/Library/Preferences/com.apple.ibtool.plist")  
      appFiles+=("/Library/Developer/CommandLineTools")
      appFiles+=("/usr/local/bin/xcode-select")
      appFiles+=("/usr/local/bin/xcodebuild")   
      appReceipts+=("com.apple.pkg.XcodeSystemResources")
      appReceipts+=("com.apple.pkg.Xcode")
      appReceipts+=("com.apple.pkg.Xcode_XR")
      ;;
xcreds)
      appTitle="XCreds"
      appProcess+=("XCreds")
      appFiles+=("/Applications/XCreds.app")
      appFiles+=("/Library/Application Support/xcreds")
      appFiles+=("/Library/LaunchAgents/com.twocanoes.xcreds-overlay.plist")
      appFiles+=("<<Users>>/Library/Caches/com.twocanoes.xcreds")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.twocanoes.xcreds")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.twocanoes.xcreds.binarycookies")
      appFiles+=("<<Users>>/Library/Logs/xcreds.log")
      appFiles+=("<<Users>>/Library/Preferences/com.twocanoes.xcreds.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.twocanoes.xcreds")
      preflightCommand+=("/Applications/XCreds.app/Contents/Resources/xcreds_login.sh -r")
      ;;
zoom)
      appTitle="Zoom"
      appProcesses=("zoom.us")
      appFiles+=("/Applications/zoom.us.app")
      appFiles+=("<<Users>>/Applications/zoom.us.app")
      appFiles+=("/Library/Internet Plug-Ins/ZoomUsPlugIn.plugin")
      appFiles+=("<<Users>>/Library/Internet Plug-Ins/ZoomUsPlugIn.plugin")
      appFiles+=("<<Users>>/.zoomus")
      appFiles+=("<<Users>>/Library/Application Support/zoom.us")
      appFiles+=("/Library/Caches/us.zoom.xos")
      appFiles+=("<<Users>>/Library/Caches/us.zoom.xos")
      appFiles+=("<<Users>>/Library/Preferences/us.zoom.xos")
      appFiles+=("/Library/Preferences/us.zoom.xos")
      appFiles+=("/Library/Logs/zoom.us")
      appFiles+=("<<Users>>/Library/Logs/zoom.us")
      appFiles+=("/Library/Logs/zoominstall.log")
      appFiles+=("<<Users>>/Library/Logs/zoominstall.log")
      appFiles+=("/Library/Preferences/ZoomChat.plist")
      appFiles+=("<<Users>>/Library/Preferences/ZoomChat.plist")
      appFiles+=("/Library/Preferences/us.zoom.xos.plist")
      appFiles+=("<<Users>>/Library/Preferences/us.zoom.xos.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/us.zoom.xos.savedState")
      appFiles+=("<<Users>>/Library/Cookies/us.zoom.xos.binarycookies")
      appFiles+=("<<Users>>/Library/Preferences/us.zoom.xos.Hotkey.plist")
      appFiles+=("<<Users>>/Library/Preferences/us.zoom.airhost.plist")
      appFiles+=("<<Users>>/Library/Mobile Documents/iCloud~us~zoom~videomeetings")
      appFiles+=("<<Users>>/Library/Application Support/CloudDocs/session/containers/iCloud.us.zoom.videomeetings.plist")
      appFiles+=("<<Users>>/Library/Application Support/CloudDocs/session/containers/iCloud.us.zoom.videomeetings")
      appFiles+=("/Library/PrivilegedHelperTools/us.zoom.ZoomDaemon")
      appFiles+=("/Library/Audio/Plug-Ins/HAL/ZoomAudioDevice.driver")
      appFiles+=("<<Users>>/Library/Group Containers/BJ4HAAB9B3.ZoomClient3rd")
      appLaunchDaemons+=("/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist")
      ;;
*) # if no specified event/label is triggered, do nothing
      printlog "ERROR: Unknown label: $label"
      exit 1
      ;;
esac

printlog "Uninstaller started - build $BUILD_DATE"

# Parse arguments for changed variables
while [[ -n $1 ]]; do
    if [[ $1 =~ ".*\=.*" ]]; then
        # if an argument contains an = character, send it to eval
        printlog "setting variable from argument $1"
        eval $1
    fi
    # shift to next argument
    shift 1
done

# Get app version
if [ -f "${appFiles[1]}/Contents/Info.plist" ]; then
	appVersion=$(defaults read "${appFiles[1]}/Contents/Info.plist" $appVersionKey)
	appBundleIdentifier=$(defaults read "${appFiles[1]}/Contents/Info.plist" $appBundleIdentifierKey)
fi    

if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
	displayNotification "Starting to uninstall $appTitle $appVersion..." "Uninstalling $appTitle"
fi

# Running preflight commands
printlog "$appTitle - Running preflightCommand"
for precommand in "${preflightCommand[@]}"
do
    if [ "$DEBUG" -eq 0 ]; then
      	zsh -c "$precommand"
    fi
done


# Remove LaunchDaemons
printlog "Uninstalling $appTitle - LaunchDaemons"
if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
  displayNotification "Removing LaunchDaemons..." "Uninstalling in progress"
fi

for launchDaemon in "${appLaunchDaemons[@]}"
do
	removeLaunchDaemons
done


# Remove LaunchAgents
printlog "Uninstalling $appTitle - LaunchAgents"
if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
  displayNotification "Removing LaunchAgents..." "Uninstalling in progress"
fi
for launchAgent in "${appLaunchAgents[@]}"
do
	if [[ "$launchAgent" == *"<<Users>>"* ]]; then
		# remove launchAgent with expanded path
		for userfolder in $(ls /Users)
		do
			expandedPath=$(echo $launchAgent | sed "s|<<Users>>|/Users/$userfolder|g")
			removeLaunchAgents "$expandedPath"
		done
	else
		# remove path without 
		removeLaunchAgents "$launchAgent"
	fi
done


# Stop app appProcesses
printlog "Checking for blocking processes..."
if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
	displayNotification "Quitting $appTitle..." "Uninstalling in progress"
fi
if [ -n "${appProcesses[1]}" ]; then
	for process in "${appProcesses[@]}"
	do
	  quitApp
	done
else
	# use $appTitle if no separate appProcesses are defined
	process="$appTitle"
	quitApp
fi


# Remove Files and Directories
printlog "Uninstalling $appTitle - Files and Directories"
if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
	displayNotification "Removing $appTitle files..." "Uninstalling in progress"
fi
for file in "${appFiles[@]}"
do
	if [[ "$file" == *"<<Users>>"* ]]; then
		if [[ $IGNORE_USER_DIRS == 0 ]]; then
			# remove path with expanded path for all available userfolders
			for userfolder in $(ls /Users)
				do
					expandedPath=$(echo $file | sed "s|<<Users>>|/Users/$userfolder|g")
					removeFileDirectory "$expandedPath" silent
			done
		else
			printlog "Ignoring deletion of user files: $file" 
		fi
	else
		# remove real path 
		removeFileDirectory "$file"
	fi
done


# Running postflight commands
printlog "Running $appTitle - postflightCommand" 
for postcommand in "${postflightCommand[@]}"
do
    if [ "$DEBUG" -eq 0 ]; then
      	zsh -c "$postcommand"
    fi
done


if [ -n "$appBundleIdentifier" ]; then
	printlog "Checking for receipt.."
	receipts=$(pkgutil --pkgs | grep -c "$appBundleIdentifier")
	if [[ "$receipts" != "0" ]]; then
	    if [ "$DEBUG" -eq 0 ]; then
      		/usr/sbin/pkgutil --forget "$appBundleIdentifier"
    	fi	
	fi
fi


# Remove manual receipts
if [ -n "${appReceipts[1]}" ]; then
	printlog "Removing $appTitle receipts" 
	for receipt in "${appReceipts[@]}"
	do
		if [ "$DEBUG" -eq 0 ]; then
      		/usr/sbin/pkgutil --forget "$receipt"
    	fi	
	done
fi


# restart prefsd to ensure caches are cleared
/usr/bin/killall -q cfprefsd

if [[ $loggedInUser != "loginwindow" && ( $NOTIFY == "success" || $NOTIFY == "all" ) ]]; then
	displayNotification "$appTitle is uninstalled." "Uninstalling completed!"
fi
printlog "Uninstaller Finished"

