microsoftteams|\
microsoftteams2)
      appTitle="Microsoft Teams"
      appProcesses+=("MSTeams")
      appFiles+=("/Applications/Microsoft Teams.app")
      appFiles+=("/Library/Preferences/com.microsoft.teams.plist")
	  appFiles+=("<<Users>>/Library/Application Scripts/com.microsoft.teams2.widgetextension")
      appFiles+=("<<Users>>/Library/Caches/com.microsoft.teams")
      appFiles+=("<<Users>>/Library/Containers/com.microsoft.teams2")
      appFiles+=("<<Users>>/Library/Group Containers/UBF8T346G9.com.microsoft.teams")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.teams.binarycookies")
      appFiles+=("<<Users>>/Library/HTTPStorages/com.microsoft.teams")
      appFiles+=("<<Users>>/Library/Preferences/com.microsoft.teams.plist ")
      appFiles+=("<<Users>>/Library/Saved Application State/com.microsoft.teams.savedState")
      appFiles+=("<<Users>>/Library/WebKit/com.microsoft.teams")
      appLaunchDaemons+=("/Library/LaunchDaemons/com.microsoft.teams.TeamsUpdaterDaemon.plist")
      preflightCommand+=("killall 'Teams'")
      ;;
