privileges2)
      appTitle="Privileges"
      appFiles+=("/Applications/Privileges.app")
      appFiles+=("/Library/PrivilegedHelperTools/corp.sap.privileges.helper")
      appFiles+=("<<Users>>/Library/Containers/corp.sap.privileges")
      appFiles+=("<<Users>>/Library/Application Scripts/corp.sap.privileges")
      appLaunchDaemons+=("/Library/LaunchDaemons/corp.sap.privileges.watcher.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/corp.sap.privileges.daemon.plist")
      appLaunchAgents+=("/Library/LaunchAgents/corp.sap.privileges.agent.plist")
      appReceipts+=("com.sap.privileges")
      ;;
