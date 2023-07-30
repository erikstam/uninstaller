xcreds)
      appTitle="XCreds"
      appProcess+=("XCreds")
      appFiles+=("/Applications/XCreds.app")
      appFiles+=("/Library/Application Support/xcreds")
      appFiles+=("/Library/LaunchAgents/com.twocanoes.xcreds-overlay.plist")
      appFiles+=("<<Users>>/Library/Caches/com.twocanoes.xcreds")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.twocanoes.xcreds")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.twocanoes.xcreds.binarycookies")
      appFiles+=("<<Users>>/Library/Logs/xcreds.log")
      appFiles+=("<<Users>>/Library/Preferences/com.twocanoes.xcreds.plist")
      appFiles+=("<<Users>>/Library/WebKit/com.twocanoes.xcreds")
      preflightCommand+=("/Applications/XCreds.app/Contents/Resources/xcreds_login.sh -r")
      ;;
