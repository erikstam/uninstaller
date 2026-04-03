privileges2)
      appTitle="Privileges"
      appFiles+=("/Applications/Privileges.app")
      appFiles+=("/Library/PrivilegedHelperTools/corp.sap.privileges.helper")
      appFiles+=("<<Users>>/Library/Containers/corp.sap.privileges")
      appFiles+=("<<Users>>/Library/Group Containers/7R5ZEU67FQ.corp.sap.privileges")      
      appFiles+=("<<Users>>/Library/Application Scripts/corp.sap.privileges")
      appFiles+=("<<Users>>/Library/Preferences/corp.sap.privileges.agent.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/corp.sap.privileges.watcher.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/corp.sap.privileges.daemon.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/corp.sap.privileges.helper.plist")
      appLaunchAgents+=("/Library/LaunchAgents/corp.sap.privileges.agent.plist")
      appReceipts+=("corp.sap.privileges.pkg")
      ;;
