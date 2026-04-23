azuredatastudio)
      appTitle="Azure Data Studio"
      # Azure Data Studio runs as process Electron. Killing every Electron may be to dangerous
      # so i'm using a preflightCommand for that
      appProcesses+=("Azure Data Studio")
      appFiles+=("/Applications/Azure Data Studio.app")
      appFiles+=("<<Users>>/Library/Application Support/azuredatastudio")
      appFiles+=("<<Users>>/Library/Caches/com.azuredatastudio.oss")
      appFiles+=("<<Users>>/Library/Caches/com.azuredatastudio.oss.ShipIt")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.azuredatastudio.oss")
      appFiles+=("<<Users>>/Library/Preferences/com.azuredatastudio.oss.plist")
      appFiles+=("<<Users>>/Library/Saved Application State/com.azuredatastudio.oss.savedState")
      preflightCommand+=("kill -9 $(pgrep -f /Applications/Azure\ Data\ Studio.app/Contents/MacOS/Electron)")
      ;;
