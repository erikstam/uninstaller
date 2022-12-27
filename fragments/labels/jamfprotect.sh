jamfprotect)
      appTitle="JamfProtect"
      appFiles+=("/Applications/JamfProtect.app")
      appFiles+=("/Library/Application Support/JamfProtect")
      appLaunchAgents+=("/Library/LaunchAgents/com.jamf.protect.agent.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.jamf.protect.daemon.plist")
      #preflightCommand+=("/Applications/JamfProtect.app/Contents/MacOS/JamfProtect uninstall")
      ;;
