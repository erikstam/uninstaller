#!/bin/zsh

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


# - appVersionKey: (optional)
#   How we get version number from app. Default value
#     - CFBundleShortVersionString
#   other values
#     - CFBundleVersion
appVersionKey="CFBundleShortVersionString"
appBundleIdentifierKey="CFBundleIdentifier"

# MARK: Last Modification Date

# Last modification date
LAST_MOD_DATE="2022-12-27"
BUILD_DATE="Mon Jan 30 19:51:21 CET 2023"

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

removeFileDirectory() {
  if [ -f "$file" ]; then
    # file exists and can be removed
    printlog "Removing file $file"
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -f "$file"
    fi
  elif [ -d "$file" ]; then
    # it is not a file, it is a directory and can be removed
    printlog "Removing directory $file..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -Rf "$file"
    fi
  elif [ -L "$file" ]; then
    # it is an alias
    printlog "Removing alias $file..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -f "$file"
    fi
  else
    # it is not a file, alias or a directory. Don't remove.
    printlog "INFO: $file is not an existing file or folder"
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

removeLaunchAgents() {
  # remove launchAgent
  if [ -f "$launchAgent" ]; then
    # launchAgent exists and can be removed
    printlog "Removing launchAgent $launchAgent..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/launchctl asuser "$loggedInUserID" launchctl unload -F "$launchAgent"
      /bin/rm -Rf "$launchAgent"
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
        "$swiftDialog" --message "$message" --title "$title" --mini
      else
        printlog "ERROR: $swiftDialog not installed for showing notifications.  Falling back to AppleScript"
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
logLocation="/private/var/log/appAssassin.log"



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
      appFiles+=("/Applications/1Password.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/1Password")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.agilebits.onepassword.plist")
      appFiles+=("/Users/$loggedInUser/Library/Containers/1Password")
      appFiles+=("/Users/$loggedInUser/Library/Containers/1Password 7")
      appFiles+=("/Users/$loggedInUser/Library/Containers/1Password Launcher")
      appFiles+=("/Users/$loggedInUser/Library/Containers/2BUA8C4S2C.com.agilebits.onepassword7-helper")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/2BUA8C4S2C.com.agilebits")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.agilebits.onepassword7-updater")
      appFiles+=("/Users/$loggedInUser/Library/Logs/1Password")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/2BUA8C4S2C.com.agilebits")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/2BUA8C4S2C.com.agilebits.onepassword7-helper")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.agilebits.onepassword7")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.agilebits.onepassword7-launcher")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.agilebits.onepassword7.1PasswordSafariAppExtension")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.agilebits.onepasswordslsnativemessaginghost")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.agilebits.onepassword7-updater")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.apple.Safari/Extensions/")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.agilebits.onepassword4/")
      ;;
1password8)
# Needs more testing
      appTitle="1Password"
      appProcesses+=("1Password")
      appProcesses+=("1Password Extension Helper")
      appProcesses+=("1password")
      appFiles+=("/Applications/1Password.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/1Password")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.agilebits.onepassword.plist")
      appFiles+=("/Users/$loggedInUser/Library/Containers/1Password")
      appFiles+=("/Users/$loggedInUser/Library/Containers/1Password 8")
      appFiles+=("/Users/$loggedInUser/Library/Containers/1Password Launcher")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/2BUA8C4S2C.com.agilebits")
      appFiles+=("/Users/$loggedInUser/Library/Logs/1Password")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/2BUA8C4S2C.com.agilebits")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/2BUA8C4S2C.com.agilebits.onepassword-helper")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.agilebits.onepassword")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.agilebits.onepassword-launcher")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.agilebits.onepassword.1PasswordSafariAppExtension")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.agilebits.onepasswordslsnativemessaginghost")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.apple.Safari/Extensions/")
      ;;
adobeareaderdc)
      appTitle="Adobe Acrobat Reader"
      appProcesses+=("AdobeReader")
      appFiles+=("/Applications/Adobe Acrobat Reader.app")
      appFiles+=("/Library/Preferences/com.adobe.reader.DC.WebResource.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.adobe.Reader")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.adobe.Reader")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.adobe.Reader.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.adobe.Reader.savedState")
      ;;
androidstudio)
      appTitle="Android Studio"
      appProcesses+=("Android Studio")
      appFiles+=("/Applications/Android Studio.app")
      appFiles+=("/Users/$loggedInUser/.android")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.google.android.studio.savedState")
      appFiles+=("/Users/$loggedInUser/Library/Logs/Google/AndroidStudio2021.3")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.google.android.studio.plist")
      ;;
androidstudiosdk)
      appTitle="Android Studio SDK"
      appFiles+=("/Users/$loggedInUser/Library/Android/sdk")
      ;;
atom)
      appTitle="Atom"
      appProcesses+=("Atom")
      appFiles+=("/Applications/Atom.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.github.atom.plist")
      appFiles+=("/Users/$loggedInUser/.atom")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Atom")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.github.atom")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.github.atom.ShipIt")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.github.atom.savedState")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.github.atom")
      ;;
bbedit)
      appTitle="BBEdit"
      appProcesses+=("BBEdit")
      appFiles+=("/Applications/BBEdit.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/BBEdit")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.barebones.bbedit.plist")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.barebones.bbedit")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.barebones.bbedit")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.barebones.bbedit.sfl2")
      postflightCommand+=("rm -r /Users/$loggedInUser/Library/Caches/com.apple.helpd/Generated/com.barebones.bbedit.help*")
      ;;
citrixworkspace)
      appTitle="Citrix Workspace"
      appFiles+=("/Applications/Citrix Workspace.app")
      appFiles+=("/Library/Application Support/Citrix Workspace Updater")
      appFiles+=("/Library/Application Support/Citrix Receiver")
      appFiles+=("/Library/Application Support/Citrix")
      appFiles+=("/Library/Application Support/Citrix Enterprise Browser")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Citrix Workspace")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Citrix Receiver")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Citrix")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.citrix.receiver.helper")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.citrix.receiver.nomas")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.citrix.receiver.nomas")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.citrix.receiver.nomas")
      appFiles+=("/Users/$loggedInUser/Library/Logs/Citrix Workspace")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.citrix.receiver.nomas.plist")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.citrix.receiver.nomas")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.citrix.receiver.nomas.savedState")
      ;;
depnotify)
      appTitle="DEPNotify"
      appProcesses+=("DEPNotify")
      appFiles+=("/Applications/Utilities/DEPNotify.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/menu.nomad.DEPNotify.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/menu.nomad.DEPNotify")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/menu.nomad.DEPNotify")
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
dockutil)
      appTitle="Dockutil"
      appFiles+=("/usr/local/bin/dockutil")
      appReceipts+=("dockutil.cli.tool")
      ;;
drawio)
      appTitle="Draw.io"
      appProcesses+=("draw.io")
      appFiles+=("/Applications/draw.io.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/draw.io")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.jgraph.drawio.desktop.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.jgraph.drawio.desktop.ShipIt")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.jgraph.drawio.desktop")
      appFiles+=("/Users/$loggedInUser/Library/Logs/draw.io")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.jgraph.drawio.desktop.savedState")
      ;;
figma)
      appTitle="Figma"
      appProcesses+=("Figma")
      appFiles+=("/Applications/Figma.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Figma")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/figma-desktop")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.figma.Desktop.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.figma.agent")
      ;;
filemakerpro19)
      appTitle="FileMaker Pro"
      appProcesses+=("FileMaker Pro")
      appFiles+=("/Applications/FileMaker Pro.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/FileMaker")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.filemaker.client.pro12.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.filemaker.client.pro12")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.filemaker.client.pro12")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.filemaker.client.pro12.savedState")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.filemaker.client.pro12")
      appFiles+=("/Users/Shared/FileMaker/FileMaker Pro/19.0")
      ;;      
firefox)
      appTitle="FireFox"
      appProcesses+=("firefox")
      appFiles+=("/Applications/Firefox.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/org.mozilla.firefox.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/Mozilla/updates/Applications/Firefox/macAttributionData")
      appFiles+=("/Users/$loggedInUser/Library/Caches/Firefox")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/org.mozilla.firefox.savedState")
      ;;
googlechrome)
      appTitle="Google Chrome"
      appProcesses+=("Google Chrome")
      appFiles+=("/Applications/Google Chrome.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Google/Chrome")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.google.Chrome.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.google.Keystone.Agent.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.google.Keystone")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.google.SoftwareUpdate")
      appFiles+=("/Users/$loggedInUser/Library/Caches/Google")
      appFiles+=("/Users/$loggedInUser/Library/Google")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.google.Keystone")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.google.Chrome.savedState")
      appFiles+=("/Library/Google/Chrome")
      appLaunchAgents+=("/Users/$loggedInUser/Library/LaunchAgents/com.google.keystone.agent.plist")
      appLaunchAgents+=("/Users/$loggedInUser/Library/LaunchAgents/com.google.keystone.xpcservice.plist")
      ;;
icons)
      appTitle="Icons"
      appProcesses+=("Icons")
      appFiles+=("/Applications/Icons.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/7R5ZEU67FQ.corp.sap.Icons")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/corp.sap.Icons")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/corp.sap.Icons.Make-Icon-Set")
      appFiles+=("/Users/$loggedInUser/Library/Containers/corp.sap.Icons")
      appFiles+=("/Users/$loggedInUser/Library/Containers/corp.sap.Icons.Make-Icon-Set")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/7R5ZEU67FQ.corp.sap.Icons")
      ;;
imovie)
      appTitle="iMovie"
      appProcesses+=("iMovie")
      appFiles+=("/Applications/iMovie.app")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.apple.iMovieApp")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.apple.iMovieApp")
      ;;
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
jamfpro)
      appTitle="Jamf Pro"
      appProcesses+=("Composer")
      appProcesses+=("Jamf Admin")
      appProcesses+=("Jamf Remote")
      appProcesses+=("Recon")
      appFiles+=("/Applications/Jamf Pro")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.jamfsoftware.admin.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.jamfsoftware.Composer.plist")
      appFiles+=("/Library/Application Support/JAMF/Composer")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.jamfsoftware.Composer.savedState")
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
java8oracle)
      appTitle="Java 8"
      appProcesses+=("java")
      appFiles+=("/Library/Application Support/Oracle/Java")
      appFiles+=("/Library/Internet Plug-Ins/JavaAppletPlugin.plugin")
      appFiles+=("/Library/PreferencePanes/JavaControlPanel.prefPane")
      appFiles+=("/Library/Preferences/com.oracle.java.Helper-Tool.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/Oracle.MacJREInstaller")    
      appFiles+=("/Users/$loggedInUser/Library/Application\ Support/Oracle/Java")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.oracle.java.JavaAppletPlugin.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.oracle.javadeployment.plist")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Oracle/Java")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/JREInstaller")                       
      appLaunchAgents+=("/Library/LaunchAgents/com.oracle.java.Java-Updater.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.oracle.java.Helper-Tool.plist")
      appReceipts+=("com.oracle.jre")
      ;;
microsoftdefender)
      appTitle="Microsoft Defender"
      appProcesses+=("wdav")
      appFiles+=("/Applications/Microsoft Defender.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.wdav.mainux.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.wdav.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.wdav.tray.plist")
      appFiles+=("/Library/Preferences/com.microsoft.wdav.tray.plist")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.microsoft.wdav.tray")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.microsoft.wdav.mainux")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/UBF8T346G9.com.microsoft.wdav")
      appLaunchAgents+=("/Library/LaunchAgents/com.microsoft.wdav.tray.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.fresno.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.fresno.uninstall.plist")
      ;;
microsoftedge)
      appTitle="Microsoft Edge"
      appFiles+=("/Applications/Microsoft Edge.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Microsoft Edge")
      appFiles+=("/Users/$loggedInUser/Library/Caches/Microsoft Edge")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.microsoft.edgemac.savedState")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.microsoft.edgemac")
      appFiles+=("/Users/$loggedInUser/Library/Microsoft/EdgeUpdater")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.edgemac.plist")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.microsoft.edgemac")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.microsoft.edgemac.wdgExtension")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.microsoft.edgemac.wdgExtension")
      appFiles+=("/Library/Microsoft/Edge")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Microsoft/EdgeUpdater")
      appLaunchAgents+=("/Users/$loggedInUser/Library/LaunchAgents/com.microsoft.EdgeUpdater.update.plist")
      postflightCommand+=("rm /Users/$loggedInUser/Library/LaunchAgents/com.microsoft.EdgeUpdater.*")
      ;;
microsoftremotedesktop)
      appTitle="Microsoft Remote Desktop"
      appProcesses+=("Microsoft Remote Desktop")
      appFiles+=("/Applications/Microsoft Remote Desktop.app")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.microsoft.rdc.macos")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.microsoft.rdc.macos.qlx")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/UBF8T346G9.com.microsoft.rdc")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/UBF8T346G9.com.microsoft.oneauth")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.microsoft.rdc.macos.qlx")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.microsoft.rdc.macos")
      ;;
mindmanager)
      appTitle="MindManager"
      appProcesses+=("MindManager")
      appFiles+=("/Applications/MindManager.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/MindManager")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.mindjet.mindmanager.22.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.mindjet.mindmanager.22")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.mindjet.mindmanager.22.binarycookies")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.mindjet.mindmanager.22.savedState")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.mindjet.mindmanager.22")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.mindjet.mindmanager.22.sfl2")
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
      appFiles+=("/Users/$loggedInUser//Library/Preferences/com.oracle.workbench.MySQLWorkbench.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.oracle.workbench.MySQLWorkbench.savedState")
      # unsure what to do with the Application Support folder because it contains the connections file...
      # appFiles+=("/Users/$loggedInUser/Library/Application Support/MySQL") 
      ;;
nomad)
      appTitle="NoMAD"
      appProcesses+=("NoMAD")
      appFiles+=("/Applications/NoMAD.app")
      appLaunchAgents+=("/Library/LaunchAgents/com.trusourcelabs.NoMAD.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.trusourcelabs.NoMAD.plist")
      ;;
nudge)
      appTitle="Nudge"
      appProcesses+=("Nudge")
      appFiles+=("/Applications/Utilities/Nudge.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.github.macadmins.Nudge.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.github.macadmins.Nudge.plist")
      ;;
postman)
      appTitle="Postman"
      appProcesses+=("Postman")
      appFiles+=("/Applications/Postman.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Postman")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.postmanlabs.mac.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.postmanlabs.mac.savedState")
      ;;
privileges)
      appTitle="Privileges"
      appFiles+=("/Applications/Privileges.app")
      appFiles+=("/Library/PrivilegedHelperTools/corp.sap.privileges.helper")
      appFiles+=("/Users/$loggedInUser/Library/Containers/corp.sap.privileges")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/corp.sap.privileges")
      appLaunchDaemons+=("/Library/LaunchDaemons/corp.sap.privileges.helper.plist")
      appLaunchAgents+=("/Library/LaunchAgents/corp.sap.privileges.plist")
      ;;
proxyman)
      appTitle="Proxyman"
      appProcesses+=("Proxyman")
      appFiles+=("/Applications/Proxyman.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.proxyman.iconappmanager.userdefaults.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.proxyman.NSProxy.plist")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.proxyman.NSProxy")
      appFiles+=("/Users/$loggedInUser/Library/Caches/Proxyman")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.proxyman.NSProxy")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.proxyman.NSProxy")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.proxyman.NSProxy.savedState")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.proxyman.NSProxy")
      appFiles+=("/Library/LaunchDaemons/com.proxyman.NSProxy.HelperTool.plist")
      appFiles+=("/Library/PrivilegedHelperTools/com.proxyman.NSProxy.HelperTool")
      ;;
pycharmce)
      appTitle="PyCharm CE"
      appProcesses+=("pycharm")
      appFiles+=("/Applications/PyCharm CE.app")
      appReceipts+=("com.jetbrains.pycharm.ce")     
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.jetbrains.pycharm.ce.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.jetbrains.pycharm.ce.savedState")
      ;;     
silverlight)
      appTitle="Silverlight"
      appProcesses+=("SLLauncher")
      appFiles+=("/Library/Application Support/Microsoft/Silverlight/OutOfBrowser/SLLauncher.app")
      appFiles+=("/Library/Application Support/Microsoft/Silverlight")
      appFiles+=("/Library/Internet Plug-Ins/Silverlight.plugin")
      appReceipts+=("com.microsoft.Silverlightinstaller")
      ;;
sketch)
      appTitle="Sketch"
      appFiles+=("/Applications/Sketch.app")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.bohemiancoding.sketch3")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.bohemiancoding.sketch3.savedState")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.bohemiancoding.sketch3.plist")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.bohemiancoding.sketch3") 
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.bohemiancoding.sketch3.QuickLook-Thumbnail")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.bohemiancoding.sketch3.QuickLook-Preview")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.bohemiancoding.sketch3")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.bohemiancoding.sketch3")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.bohemiancoding.sketch3.QuickLook-Thumbnail")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.bohemiancoding.sketch3.QuickLook-Preview")
      ;;
skype)
      appTitle="Skype"
      appFiles+=("/Applications/Skype.app")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.skype.skype/")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.skype.skype.ShipIt/")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.skype.skype")
      appFiles+=("/Users/$loggedInUser/Library/Logs/Skype Helper (Renderer)")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.skype.skype.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.skype.skype.savedState")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Microsoft/Skype for Desktop")
      ;;
sourcetree)
      appTitle="Sourcetree"
      appFiles+=("/Applications/Sourcetree.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/sourcetree/")
      appFiles+=("/Users/$loggedInUser/Library/Logs/sourcetree/")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.torusknot.SourceTreeNotMAS")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.torusknot.SourceTreeNotMAS.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.torusknot.SourceTreeNotMAS.savedState")
      ;;
spotify)
      appTitle="Spotify"
      appFiles+=("/Applications/Spotify.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Spotify/")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.spotify.client")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.spotify.client.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.spotify.client.savedState")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.spotify.client")
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
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/nl.root3.support")
      appFiles+=("/Users/$loggedInUser/Library/Containers/nl.root3.support")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/nl.root3.support.sfl2")
      appLaunchAgents+=("/Library/LaunchAgents/nl.root3.support.plist")
      ;;
teamviewer)
      appTitle="TeamViewer"
      appProcesses+=("TeamViewer")
      appFiles+=("/Applications/TeamViewer.app")
      appFiles+=("/Library/Application Support/TeamViewer/")
      appFiles+=("/Library/PrivilegedHelperTools/com.teamviewer.Helper")
      appFiles+=("/Library/Preferences/com.teamviewer.teamviewer.preferences.plist")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/TeamViewer/")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.teamviewer.TeamViewer.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.teamviewer.teamviewer.preferences.Machine.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.teamviewer.teamviewer.preferences.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/TeamViewer/")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.teamviewer.TeamViewer")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.teamviewer.TeamViewer")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.teamviewer.Helper.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.teamviewer.teamviewer_service.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.teamviewer.teamviewer_desktop.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.teamviewer.teamviewer.plist")
      appReceipts+=("com.teamviewer.teamviewer")
      appReceipts+=("com.teamviewer.teamviewerPriviledgedHelper")
      appReceipts+=("com.teamviewer.remoteaudiodriver")     
      appReceipts+=("com.teamviewer.AuthorizationPlugin")
      ;;
textwrangler)
      appTitle="TextWrangler"
      appProcesses+=("TextWrangler")
      appFiles+=("/Applications/TextWrangler.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/TextWrangler")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.barebones.textwrangler.plist")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.barebones.textwrangler")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.barebones.textwrangler")
      appFiles+=("/usr/local/bin/edit")
      appFiles+=("/usr/local/bin/twdiff")
      appFiles+=("/usr/local/bin/twfind")
      ;;
visualstudiocode)
      appTitle="Visual Studio Code"
      # appProcesses+=("Code") # Electron app...
      appFiles+=("/Applications/Visual Studio Code.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Code")
      appFiles+=("/Users/$loggedInUser/.vscode")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.VSCode.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.microsoft.VSCode.savedState")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.microsoft.vscode.sfl2")
      ;;
vlc)
      appTitle="VLC"
      appProcess+=("VLC")
      appFiles+=("/Applications/VLC.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/org.videolan.vlc")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/org.videolan.vlc.plist")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/org.videolan.vlc")
      appFiles+=("/Users/$loggedInUser/Library/Caches/org.videolan.vlc")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/org.videolan.vlc")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/org.videolan.vlc.savedState")
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
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.wacom.ProfessionalTablet.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.wacom.wacomtablet.prefs")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.wacom.wacomtouch.prefs")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/EG27766DY7.com.wacom.WacomTabletDriver")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/com.wacom.TabletDriver")
      appLaunchAgents+=("/Library/LaunchAgents/com.wacom.DataStoreMgr.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.wacom.IOManager.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.wacom.wacomtablet.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.wacom.UpdateHelper.plist")
     ;;
whatsapp)
      appTitle="WhatsApp"
      appFiles+=("/Applications/WhatsApp.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/WhatsApp")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/net.whatsapp.WhatsApp")
      appFiles+=("/Users/$loggedInUser/Library/Caches/WhatsApp")
      appFiles+=("/Users/$loggedInUser/Library/Caches/WhatsApp.ShipIt")
      appFiles+=("/Users/$loggedInUser/Library/Containers/net.whatsapp.WhatsApp")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/WhatsApp.savedState")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/group.net.whatsapp.WhatsApp.private")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/group.com.facebook.family")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/group.net.whatsapp.WhatsAppSMB.shared")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/group.net.whatsapp.WhatsAppSMB.private")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/group.net.whatsapp.family")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/WhatsApp.plist")
      ;;
windscribe)
      appTitle="Windscribe"
      appFiles+=("/Applications/Windscribe.app")
      appFiles+=("/Library/PrivilegedHelperTools/com.windscribe.helper.macos")
      appFiles+=("/Library/Logs/com.windscribe.helper.macos")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.windscribe.launcher.macos")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Windscribe")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.windscribe.launcher.macos")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.windscribe.Windscribe2.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.windscribe.gui.macos.savedState")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.windscribe.helper.macos.plist")
      ;;
xcreds)
      appTitle="XCreds"
      appProcess+=("XCreds")
      appFiles+=("/Applications/XCreds.app")
      appFiles+=("/Library/Application Support/xcreds")
      appFiles+=("/Library/LaunchAgents/com.twocanoes.xcreds-overlay.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.twocanoes.xcreds")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.twocanoes.xcreds")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.twocanoes.xcreds.binarycookies")
      appFiles+=("/Users/$loggedInUser/Library/Logs/xcreds.log")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.twocanoes.xcreds.plist")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.twocanoes.xcreds")
      preflightCommand+=("/Applications/XCreds.app/Contents/Resources/xcreds_login.sh -r")
      ;;
zoom)
      appTitle="Zoom"
      appProcesses=("zoom.us")
      appFiles+=("/Applications/zoom.us.app")
      appFiles+=("/Users/$loggedInUser/Applications/zoom.us.app")
      appFiles+=("/Library/Internet Plug-Ins/ZoomUsPlugIn.plugin")
      appFiles+=("/Users/$loggedInUser/Library/Internet Plug-Ins/ZoomUsPlugIn.plugin")
      appFiles+=("/Users/$loggedInUser/.zoomus")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/zoom.us")
      appFiles+=("/Library/Caches/us.zoom.xos")
      appFiles+=("/Users/$loggedInUser/Library/Caches/us.zoom.xos")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/us.zoom.xos")
      appFiles+=("/Library/Preferences/us.zoom.xos")
      appFiles+=("/Library/Logs/zoom.us")
      appFiles+=("/Users/$loggedInUser/Library/Logs/zoom.us")
      appFiles+=("/Library/Logs/zoominstall.log")
      appFiles+=("/Users/$loggedInUser/Library/Logs/zoominstall.log")
      appFiles+=("/Library/Preferences/ZoomChat.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/ZoomChat.plist")
      appFiles+=("/Library/Preferences/us.zoom.xos.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/us.zoom.xos.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/us.zoom.xos.savedState")
      appFiles+=("/Users/$loggedInUser/Library/Cookies/us.zoom.xos.binarycookies")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/us.zoom.xos.Hotkey.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/us.zoom.airhost.plist")
      appFiles+=("/Users/$loggedInUser/Library/Mobile Documents/iCloud~us~zoom~videomeetings")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/CloudDocs/session/containers/iCloud.us.zoom.videomeetings.plist")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/CloudDocs/session/containers/iCloud.us.zoom.videomeetings")
      appFiles+=("/Library/PrivilegedHelperTools/us.zoom.ZoomDaemon")
      appFiles+=("/Library/Audio/Plug-Ins/HAL/ZoomAudioDevice.driver")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/BJ4HAAB9B3.ZoomClient3rd")
      appLaunchDaemons+=("/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist")
      ;;
*) # if no specified event/label is triggered, do nothing
      printlog "ERROR: Unknown label: $label"
      exit 1
      ;;
esac

printlog "Uninstaller started - version $LAST_MOD_DATE (build: $BUILD_DATE)"

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
	removeLaunchAgents
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
  removeFileDirectory
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
/usr/bin/killall -q cfprefs

if [[ $loggedInUser != "loginwindow" && ( $NOTIFY == "success" || $NOTIFY == "all" ) ]]; then
	displayNotification "$appTitle is uninstalled." "Uninstalling completed!"
fi
printlog "Uninstaller Finished"

