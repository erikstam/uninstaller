sonoss2)
      # Keep label the same as the Installomator label	
      appTitle="Sonos"      
      appProcesses+=("Sonos")
      appFiles+=("/Applications/Sonos.app")
      appFiles+=("<<Users>>/Library/Caches/com.sonos.macController2")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.sonos.macController2")
      appFiles+=("<<Users>>/Library/Logs/Sonos")
      appFiles+=("<<Users>>/Library/Logs/Sonos Installer")
      appFiles+=("<<Users>>/Library/Preferences/com.sonos.macController2.plist")
      preflightCommand+=("kill -9 $(pgrep -f 'Sonos')")
      ;;
