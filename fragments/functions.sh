# MARK: Functions

printlog() {
  timestamp=$(/bin/date +%F\ %T)
  
  if [ "$(whoami)" = "root" ]; then
    echo "$timestamp" "$1" | tee -a "$logLocation"
  else
    echo "$timestamp" "$1"
  fi
}

runAsUser() {
  if [ "$loggedInUser" != "loginwindow" ]; then
    uid=$(id -u "$loggedInUser")
    /bin/launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"
  fi
}

quitApp() {
  processStatus=$( /usr/bin/pgrep -x "$process")
  if [ "$processStatus" ]; then
    printlog "Found blocking process $process"
    
    if [ "$DEBUG" -eq 0 ]; then
      printlog "Stopping process $process"
      #runAsUser osascript -e "tell app \"$process\" to quit"
      # pkill "$process"
      /usr/bin/killall "$process"
    fi
  else
    printlog "Found no blocking process..."
  fi
}

removeFileDirectory() {
  if [ -f "$file" ]; then
    # file exists and can be removed
    printlog "Removing file $file"
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -f "$file"
    fi
  elif [ -d "$file" ]; then
    # it is not a file, it is a directory and can be removed
    printlog "Removing directory $file..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -Rf "$file"
    fi
  elif [ -L "$file" ]; then
    # it is an alias
    printlog "Removing alias $file..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -f "$file"
    fi
  else
    # it is not a file, alias or a directory. Don't remove.
    printlog "INFO: $file is not an existing file or folder"
  fi
}

removeLaunchDaemons() {
  # remove LaunchDaemon
  if [ -f "$launchDaemon" ]; then
    # LaunchDaemon exists and can be removed
    printlog "Removing launchDaemon $launchDaemon..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/launchctl unload "$launchDaemon"
      /bin/rm -Rf "$launchDaemon"
    fi
  fi
}

removeLaunchAgents() {
  # remove launchAgent
  if [ -f "$launchAgent" ]; then
    # launchAgent exists and can be removed
    printlog "Removing launchAgent $launchAgent..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/launchctl asuser "$loggedInUserID" launchctl unload -F "$launchAgent"
      /bin/rm -Rf "$launchAgent"
    fi
  fi
}

displayNotification() { # $1: message $2: title
  
  message=${1:-"Message"}
  title=${2:-"Notification"}
  FallBacktoAS=false
  
  case $NOTIFICATIONTYPE in
    jamf)
      if [ -x "$jamfManagementAction" ]; then
        "$jamfManagementAction" -message "$message" -title "$title"
      else
        printlog "ERROR: $jamfManagementAction not installed for showing notifications. Falling back to AppleScript"
        FallBacktoAS=true
      fi
    ;;
    swiftdialog)
      if [ -x "$swiftDialog" ]; then
        "$swiftDialog" --message "$message" --title "$title" --mini
      else
        printlog "ERROR: $swiftDialog not installed for showing notifications.  Falling back to AppleScript"
      fi
    ;;
    applescript)
      FallBacktoAS=true
    ;;		
    *) # unknown NOTIFICATIONTYPE, using applescript
      FallBacktoAS=true
    ;;
  esac
  
  if [[ "$FallBacktoAS" == true ]]; then
  	runAsUser osascript -e "display notification \"$message\" with title \"$title\""
  fi
  
}

