logitechghub|\
logighub)
      appTitle="Logitech G HUB"
      appProcesses+=("lghub_ui" "lghub_agent" "logi_crashpad_handler" "lghub_updater" "lghub_system_tray" "lghub_sso_handler")
      appFiles+=("/Applications/lghub.app")
      appFiles+=("/Users/Shared/LGHUB")
      appFiles+=("<<Users>>/Library/Application Support/G HUB")
      appFiles+=("<<Users>>/Library/Application Support/LGHUB")
      appFiles+=("<<Users>>/Library/Caches/com.logi.ghub.installer")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.logi.ghub.installer")
      appFiles+=("<<Users>>/Library/Preferences/com.logi.ghub.ui.plist")
      appLaunchAgents+=("/Library/LaunchAgents/com.logi.ghub.plist")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.logi.ghub.updater.plist")
      ;;
