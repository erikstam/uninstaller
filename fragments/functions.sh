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
      # small delay after kill action
      sleep 3
    fi
  else
    printlog "Found no blocking process..."
  fi
}

removeFileDirectory() { # $1: object $2: logmode
    object=${1:-"Object"}
    logmode=${2:-"Log Mode"}
  if [ -f "$object" ]; then
    # file exists and can be removed
    printlog "Removing file $object"
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -f "$object"
    fi
  elif [ -d "$object" ]; then
    # it is not a file, it is a directory and can be removed
    printlog "Removing directory $object..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -Rf "$object"
    fi
  elif [ -L "$object" ]; then
    # it is an alias
    printlog "Removing alias $object..."
    if [ "$DEBUG" -eq 0 ]; then
      /bin/rm -f "$object"
    fi
  else
    # it is not a file, alias or a directory. Don't remove.
    if [ "$logmode" != "silent" ]; then
    	printlog "INFO: $object is not an existing file or folder"
    fi
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

removeLaunchAgents() { # $1: object
    object=${1:-"Object"}
  # remove launchAgent
  if [ -f "$object" ]; then
    # launchAgent exists and can be removed
    
    if [ "$DEBUG" -eq 0 ]; then
   		service_name=$(defaults read $object Label)
		rootfolder=$(echo $object | awk -F/ '{print $2}')
		if [[ "$rootfolder" == "Users" ]]; then
			user_name=$(echo $object | awk -F/ '{print $3}')
		else
			user_name=$loggedInUser
		fi
		
		user_uid=$( /usr/bin/id -u "$user_name" )	
		# unload
    	if launchctl print "gui/${user_uid}/${service_name}" &> /dev/null ; then
    		printlog "unloading $object for $user_name"
    		launchctl bootout gui/${user_uid} "$object" &> /dev/null
    		# or the old fashioned way
      		#/bin/launchctl asuser "$user_uid" launchctl unload -F "$object"
		fi
		printlog "Removing launchAgent $object..."
    	/bin/rm -Rf "$object"
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

