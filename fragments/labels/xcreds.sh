xcreds)
      appTitle="XCreds"
      appProcess+=("XCreds")
      appFiles+=("/Applications/XCreds.app")
      appFiles+=("/Library/Application Support/xcreds")
      appFiles+=("/Library/LaunchAgents/com.twocanoes.xcreds-overlay.plist")
      appFiles+=("/Users/$loggedInUser/Library/Caches/com.twocanoes.xcreds")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.twocanoes.xcreds")
      appFiles+=("/Users/$loggedInUser/Library/HTTPStorages/com.twocanoes.xcreds.binarycookies")
      appFiles+=("/Users/$loggedInUser/Library/Logs/xcreds.log")
      appFiles+=("/Users/$loggedInUser/Library/Preferences/com.twocanoes.xcreds.plist")
      appFiles+=("/Users/$loggedInUser/Library/WebKit/com.twocanoes.xcreds")
      preflightCommand+=("/Applications/XCreds.app/Contents/Resources/xcreds_login.sh -r")
      ;;
