adobedigitaleditions)
# Needs more testing
      appTitle="Adobe Digital Editions"
      appProcesses+=("Adobe Digital Editions")
      appFiles+=("/Applications/Adobe Digital Editions.app")
      adobedigitaleditionsSymlinkDestination=$(readlink "/Applications/Adobe Digital Editions.app")
      appFiles+=("${adobedigitaleditionsSymlinkDestination}")
      appFiles+=("<<Users>>/Library/Preferences/com.adobe.adobedigitaleditions.app.plist")
      ;;
