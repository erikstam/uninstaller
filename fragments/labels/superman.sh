superman)
      appTitle="superman"
      appProcesses+=("super")
      appFiles+=("/Library/Management/super")
      appFiles+=("/usr/local/bin/super")
      appFiles+=("/var/run/super.pid")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.macjutsu.super.plist")
      preflightCommand+=("/Library/Management/super/super --reset-super --auth-delete-all")
      ;;
