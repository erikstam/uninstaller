nordvpn)
      appTitle="NordVPN"      
      appProcesses+=("NordVPN")
      appFiles+=("/Applications/NordVPN.app")
      appFiles+=("/Library/PrivilegedHelperTools/com.nordvpn.macos.helper")
      appFiles+=("<<Users>>/Application Support/com.nordvpn.macos")
      appFiles+=("<<Users>>/Caches/com.nordvpn.macos")
      appFiles+=("<<Users>>/HTTPStorages/com.nordvpn.macos")
      appFiles+=("<<Users>>/Preferences/com.nordvpn.macos.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.nordvpn.macos.helper.plist")
      appReceipts+=("com.nordvpn.macos")
      ;;
