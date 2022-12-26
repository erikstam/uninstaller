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
