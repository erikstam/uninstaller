setupmanager)
      appTitle="Setup Manager"
      appProcesses+=("Setup Manager")
      appFiles+=("/Applications/Utilities/Setup Manager.app")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.jamf.setupmanager.plist")
      appLaunchAgents+=("/Library/LaunchDaemons/com.jamf.setupmanager.loginwindow.plist")
      appFiles+=("/Library/Logs/Setup Manager.log")
      appFiles+=("<<Users>>/Library/Caches/com.jamf.setupmanager")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.jamf.setupmanager")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.jamf.setupmanager.binarycookies")
      appFiles+=("<<Users>>/Library/Caches/com.jamf.setupmanager")
      # as Setup Manager runs at enrollment or at the login window it will store its files
      # in the root directory
      appFiles+=("/private/var/root/Library/Caches/com.jamf.setupmanager")
      appFiles+=("/private/var/root/Library/HTTPStorages/com.jamf.setupmanager")
      appFiles+=("/private/var/root/Library/HTTPStorages/com.jamf.setupmanager.binarycookies")
      appFiles+=("/private/var/root/Library/Caches/com.jamf.setupmanager")
      appReceipts+=("com.jamf.setupmanager")
      ;;
