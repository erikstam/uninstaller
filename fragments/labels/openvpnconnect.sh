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
