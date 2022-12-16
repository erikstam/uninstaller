#!/bin/zsh

# Uninstaller script

# Last modification date
LAST_MOD_DATE="2022-12-16"

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



#######################
# Functions
#######################

uninstallApp() {
  # Check which event is triggered and add extra information.
  case $1 in
1password)
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
adobeacrobatdc)
      appTitle="Adobe Acrobat DC"
      appProcesses+=("Adobe Acrobat")
      preflightCommand+=("/Applications/Adobe Acrobat DC/Adobe Acrobat.app/Contents/Helpers/Acrobat Uninstaller.app/Contents/Library/LaunchServices/com.adobe.Acrobat.RemoverTool /Applications/Adobe Acrobat DC/Adobe Acrobat.app/Contents/Helpers/Acrobat Uninstaller.app/Contents/MacOS/Acrobat Uninstaller /Applications/Adobe Acrobat DC/Adobe Acrobat.app")
      ;;
adobeacrobat2017)
      appTitle="Adobe Acrobat 2017"
      appProcesses+=("Adobe Acrobat")
      preflightCommand+=("/Applications/Adobe Acrobat 2017/Adobe Acrobat.app/Contents/Helpers/Acrobat Uninstaller.app/Contents/Library/LaunchServices/com.adobe.Acrobat.RemoverTool Uninstall /Applications/Adobe Acrobat 2017/Adobe Acrobat.app")
      ;;
androidstudio)
      appTitle="Android Studio"
      appProcesses+=("Android Studio")
      appFiles+=("/Applications/Android Studio.app")
      ;;
atlassiancompanion)
      appTitle="Atlassian Companion"
      appProcesses+=("Atlassian Companion")
      appFiles+=("/Applications/Atlassian Companion.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Atlassian Companion")
      ;;
atom)
      appTitle="Atom"
      appProcesses+=("Atom")
      appFiles+=("/Applications/Atom.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.github.atom.plist")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Atom")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.github.atom")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.github.atom.ShipIt")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.github.atom.savedState")
      ;;
axurerp8)
      appTitle="Axure RP 8"
      appProcesses+=("Axure RP 8")
      appFiles+=("/Applications/Axure RP 8.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Axure")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.axure.*.plist")
      appFiles+=("/Users/$loggedInUser/Axure/")
      appFiles+=("/Users/$loggedInUser/.local/share/Axure/")
      appFiles+=("/Users/$loggedInUser/.config/.mono/certs/")
      appFiles+=("/Users/$loggedInUser/.config/.isolated-storage/")
      ;;
axurerp9)
      appTitle="Axure RP 9"
      appProcesses+=("Axure RP 9")
      appFiles+=("/Applications/Axure RP 9.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Axure")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.axure.*.plist")
      appFiles+=("/Users/$loggedInUser/Axure/")
      appFiles+=("/Users/$loggedInUser/.local/share/Axure/")
      appFiles+=("/Users/$loggedInUser/.config/.mono/certs/")
      appFiles+=("/Users/$loggedInUser/.config/.isolated-storage/")
      ;;
bbedit)
      appTitle="BBEdit"
      appProcesses+=("BBEdit")
      appFiles+=("/Applications/BBEdit.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/BBEdit")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.barebones.bbedit.plist")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.barebones.bbedit")
      ;;
citrixendpointanalysis)
      appTitle="Citrix Endpoint Analysis"
      ;;
citrixworkspace)
      appTitle="Citrix Workspace"
      appFiles+=("/Applications/Citrix Workspace.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Citrix Workspace")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/com.citrix.receiver.nomas")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.citrix.receiver.nomas")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.citrix.receiver.nomas")
      appFiles+=("/Users/$loggedInUser/Library/Logs/Citrix Workspace")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.citrix.receiver.nomas.plist")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.citrix.receiver.nomas.plist")
      ;;
depnotify)
      appTitle="DEPNotify"
      appProcesses+=("DEPNotify")
      appFiles+=("/Applications/Utilities/DEPNotify.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/menu.nomad.DEPNotify.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/menu.nomad.DEPNotify")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/menu.nomad.DEPNotify")
      ;;
desktoppr)
      appTitle="Desktoppr"
      appFiles+=("/usr/local/bin/desktoppr")
      ;;
docker)
      appTitle="Docker Desktop"
      appProcesses+=("Docker")
      appProcesses+=("Docker Desktop")
      appProcesses+=("com.docker.hyperkit")
      appFiles+=("/Applications/Utilities/Docker.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/com.docker.helper")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.docker.docker")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.docker.docker")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.docker.helper")
      appFiles+=("/Library/PrivilegedHelperTools/com.docker.vmnetd")
      appFiles+=("/Users/$loggedInUser/.docker")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Docker Desktop")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.docker.docker.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.electron.docker-frontend.savedState")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/group.com.docker")
      appFiles+=("/Users/$loggedInUser/Library/Logs/Docker Desktop")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.electron.docker-frontend.plist")
      appFiles+=("/Users/$loggedInUser/Library/Cookies/com.docker.docker.binarycookies")
      appFiles+=("/usr/local/lib/docker")
      appFiles+=("/usr/local/bin/docker-machine")
      appFiles+=("/usr/local/bin/docker-compose")
      appFiles+=("/usr/local/bin/docker-credential-osxkeychain")
      appFiles+=("/usr/local/lib/docker")
      appLaunchAgents+=("/Library/LaunchDaemons/com.docker.vmnetd.plist")
      preflightCommand+=("/Applications/Docker.app/Contents/MacOS/Docker --uninstall")
      ;;
dockutil)
      appTitle="Dockutil"
      appFiles+=("/usr/local/bin/dockutil")
      ;;
drawio)
# Last checked: 09-03-2022
      appTitle="Draw.io"
      appFiles+=("/Applications/Drawio.app")
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
      appFiles+=("/Users/Shared/FileMaker/FileMaker Pro/19.0")
      ;;      
firefox)
      appTitle="FireFox"
      appProcesses+=("firefox")
      appFiles+=("/Applications/Firefox.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/org.mozilla.firefox.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/Mozilla/updates/Applications/Firefox/macAttributionData")
      appFiles+=("/Users/$loggedInUser/Library/Caches/Firefox")
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
      appFiles+=("/Users/$loggedInUser/Library/Application Scrips/corp.sap.Icons")
      ;;
imovie)
      appTitle="iMovie"
      appProcesses+=("iMovie")
      appFiles+=("/Applications/iMovie.app")
      ;;
invisionstudio)
      appTitle="InVision Studio"
      appProcesses+=("InVision Studio")
      appFiles+=("/Applications/InVision Studio.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/InVision Studio")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/invision.invision-studio.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/Containers/Icons")
      ;;
jamfconnect)
      appTitle="Jamf Connect"
      appProcesses+=("Jamf Connect")
      appFiles+=("/Applications/Jamf Connect.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/JamfConnect")
      appFiles+=("/usr/local/bin/authchanger")
      appFiles+=("/usr/local/lib/pam/pam_saml.so.2")
      appFiles+=("/Library/Security/SecurityAgentPlugins/JamfConnectLogin.bundle")
      appFiles+=("/Library/Application Support/JamfConnect")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.connect.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.connect.unlock.login.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.jamf.connect.daemon.plist")
      preflightCommand+=("/usr/local/bin/authchanger -reset")
      postflightCommand+=("")
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
      ;;
jamfprotect)
      appTitle="JamfProtect"
      appFiles+=("/Applications/JamfProtect.app")
      appFiles+=("/Library/Application Support/JamfProtect")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.protect.agent.plist")
      preflightCommand+=("/Applications/JamfProtect.app/Contents/MacOS/JamfProtect uninstall")
      ;;
java8oracle)
      appTitle="Java 8"
      appProcesses+=("java")
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
jetbrainsintellijidea)
      appTitle="JetBrains IntelliJ IDEA"
      appProcesses+=("IntelliJ IDEA")
      appFiles+=("/Applications/IntelliJ IDEA.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/JetBrains/IntelliJIdea2021.3")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.jamfsoftware.admin.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.jamfsoftware.admin.plist")
      ;;
jetbrainspycharm)
      appTitle="JetBrains PyCharm"
      appProcesses+=("PyCharm")
      appFiles+=("/Applications/PyCharm.app")
      ;;
kalturacapture)
      appTitle="Kaltura Capture"
      appProcesses+=("KalturaCapture")
      appFiles+=("/Applications/KalturaCapture.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/lecture-capture-app")
      ;;
microsoftdefender)
      appTitle="Microsoft Defender"
      appProcesses+=("wdav")
      appFiles+=("/Applications/Microsoft Defender.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.wdav.mainux.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.wdav.plist")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.wdav.tray.plist")
      appFiles+=("/Library/Preferences/com.microsoft.wdav.tray.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.microsoft.wdav.tray.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.fresno.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.fresno.uninstall.plist")
      ;;
microsoftremotedesktop)
      appTitle="Microsoft Remote Desktop"
      appProcesses+=("Microsoft Remote Desktop")
      appFiles+=("/Applications/Microsoft Remote Desktop.app")
      appFiles+=("/Users/$loggedInUser/Library/Containers/com.microsoft.rdc.macos")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/UBF8T346G9.com.microsoft.rdc")
      ;;
microsoftedge)
      appTitle="Microsoft Edge"
      appFiles+=("/Applications/Microsoft Edge.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Microsoft Edge")
      appFiles+=("/Users/$loggedInUser/Library/Caches/Microsoft Edge")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.microsoft.edgemac.savedState")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.microsoft.edgemac")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.edgemac.plist")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.microsoft.edgemac")
      appFiles+=("/Library/Microsoft/Edge")
      ;;
microsofttodo)
      appTitle="Microsoft To Do"
      appProcesses+=("Microsoft To Do")
      appFiles+=("/Applications/Microsoft To Do.app")
      appFiles+=("/Users/$loggedInUser/Library/Group Containers/UBF8T346G9.com.microsoft.to-do-mac")
      ;;
mindjetmindmanager)
      appTitle="Mindjet MindManager"
      appProcesses+=("Mindjet MindManager")
      appFiles+=("/Applications/Mindjet MindManager.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Mindjet MindManager")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Mindjet")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.mindjet.mindmanager.12.plist")
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
nessus)
      appTitle="Nessus"
      appProcesses+=("nessusd")
      appFiles+=("/Library/NessusAgent")
      appFiles+=("/Library/PreferencePanes/Nessus Agent Preferences.prefPane")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.tenablesecurity.nessusagent.plist")
      ;;
nomad)
      appTitle="NoMAD"
      appProcesses+=("NoMAD")
      appFiles+=("/Applications/NoMAD.app")
      appLaunchAgents+=("/Library/LaunchAgents/com.trusourcelabs.NoMAD.plist")
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
      appFiles+=("/Users/$loggedInUser/Application Support/Postman")
      ;;
principle)
      appTitle="Principle"
      appProcesses+=("Principle")
      appFiles+=("/Applications/Principle.app")
      appFiles+=("/Users/$loggedInUser/Application Support/com.danielhooper.principle")
      appFiles+=("/Users/$loggedInUser/Caches/com.danielhooper.principle")
      appFiles+=("/Users/$loggedInUser/HTTPStorages/com.danielhooper.principle")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.danielhooper.principle.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.danielhooper.principle.savedState")
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
      ;;
pycharmce)
      appTitle="PyCharm CE"
      appProcesses+=("pycharm")
      appFiles+=("/Applications/PyCharm CE.app")
      appReceipts+=("com.jetbrains.pycharm.ce")     
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.jetbrains.pycharm.ce.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.jetbrains.pycharm.ce.savedState")
      ;;     
sketch)
      appTitle="Sketch"
      appFiles+=("/Applications/Sketch.app")
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
      ;;
spotify)
      appTitle="Spotify"
      appFiles+=("/Applications/Spotify.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Support/Spotify/")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.spotify.client")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.spotify.client.plist")
      appFiles+=("/Users/$loggedInUser/Library/Saved Application State/com.spotify.client.savedState")
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
supportapp)
      appTitle="Support app"
      appProcesses+=("Support")
      appFiles+=("/Applications/Support.app")
      appFiles+=("/Users/$loggedInUser/Library/Application Scripts/nl.root3.support")
      appFiles+=("/Users/$loggedInUser/Library/Containers/nl.root3.support")
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
      appLaunchDaemons+=("/Library/LaunchDaemons/com.teamviewer.Helper.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.teamviewer.teamviewer_service.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.teamviewer.teamviewer_desktop.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.teamviewer.teamviewer.plist")
      appReceipts+=("com.teamviewer.teamviewer")
      appReceipts+=("com.teamviewer.teamviewerPriviledgedHelper")
      appReceipts+=("com.teamviewer.remoteaudiodriver")     
      appReceipts+=("com.teamviewer.AuthorizationPlugin")
      ;;
verasecuserselfservice)
      appTitle="Versasec User Self-Service"
      appProcesses+=("vSEC:CMS User Self-Service")
      appFiles+=("/Applications/UssMac.app")
      ;;
visualstudiocode)
      appTitle="Visual Studio Code"
      appFiles+=("/Applications/Visual Studio Code.app")
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
      ;;
yammer)
      appTitle="Yammer"
      appProcesses+=("yammer")
      appFiles+=("/Applications/Yammer.app")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.microsoft.Yammer.plist")
      ;;
zoom)
      appTitle="Zoom"
      appProcesses=("zoom")
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
      appLaunchDaemons+=("/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist")
      ;;
    *) # if no specified event/label is triggered, do nothing
      printlog "ERROR: Unknown label: $label"
      exit 1
      ;;
  esac

  printlog "Uninstaller started - build $LAST_MOD_DATE"

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
    zsh -c "$precommand"
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
    zsh -c "$postcommand"
  done
    
  
  if [ -n "$appBundleIdentifier" ]; then
	printlog "Checking for receipt.."
	receipts=$(pkgutil --pkgs | grep -c "$appBundleIdentifier")
	if [[ "$receipts" != "0" ]]; then
		/usr/sbin/pkgutil --forget "$appBundleIdentifier"
	fi
  fi


  # Remove manual receipts
  if [ -n "${appReceipts[1]}" ]; then
  printlog "Removing $appTitle receipts" 
  for receipt in "${appReceipts[@]}"
  do
    /usr/sbin/pkgutil --forget "$receipt"
  done
  fi
  

  
  
  # restart prefsd to ensure caches are cleared
  /usr/bin/killall -q cfprefs

  if [[ $loggedInUser != "loginwindow" && ( $NOTIFY == "success" || $NOTIFY == "all" ) ]]; then
    displayNotification "$appTitle is uninstalled." "Uninstalling completed!"
  fi
  printlog "Uninstaller Finished"


}

printlog() {
  timestamp=$(/bin/date +%F\ %T)

  if [ "$(whoami)" = "root" ]; then
    echo "$timestamp" "$1" | tee -a $logLocation
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

	case $NOTIFICATIONTYPE in
		jamf)
			if [ -x "$jamfManagementAction" ]; then
				"$jamfManagementAction" -message "$message" -title "$title"
			else
				printlog "ERROR: $jamfManagementAction not installed for showing notifications."
			fi
			;;
		swiftdialog)
			if [ -x "$swiftDialog" ]; then
				"$swiftDialog" --message "$message" --title "$title" --mini
			else
				printlog "ERROR: $swiftDialog not installed for showing notifications."
			fi
			;;
		applescript)
			runAsUser osascript -e "display notification \"$message\" with title \"$title\""
			;;		
		*) # unknown NOTIFICATIONTYPE, using applescript
      		runAsUser osascript -e "display notification \"$message\" with title \"$title\""
      		;;
	esac
}


####################################
# Code
####################################

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

uninstallApp "$label"

exit 0
