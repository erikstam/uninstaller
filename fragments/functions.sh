#########################################################################################
# MARK: Functions
#########################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# NOTE: NOTE: Client-side Logging
# Priority: ALERT, ERROR, WARN, INFO, DEBUG
# Example: printlog "Logging text message" priority
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
if [[ "$(whoami)" == "root" ]]; then
    weAreSU=1
else
    weAreSU=0
fi
printlog() {
    [ -z "$2" ] && 2=INFO
    local log_message=$1
    local log_priority=$2
    local timestamp=$(date +%F\ %T)
  
    # Extra spaces for log_priority alignment
    space_char=""
    if [[ ${#log_priority} -eq 3 ]]; then
        space_char="  "
    elif [[ ${#log_priority} -eq 4 ]]; then
        space_char=" "
    fi

    if [[ $weAreSU -eq 1 ]]; then
        echo "$timestamp : ${log_priority}${space_char} : ${label} : [${funcstack[2]}] ${log_message}" | tee -a $log_location
  else
        echo "$timestamp : ${log_priority}${space_char} : ${label} : [${funcstack[2]}] ${log_message}"
  fi
}
printlog "[LOG-BEGIN] : ${scriptName} v.${LAST_MOD_DATE} (build: ${BUILD_DATE})" ALERT


# ---------------------------------------------------------------------------------------
# Run commands as loggedInUser
# ---------------------------------------------------------------------------------------
runAsUser() {
  if [ "$loggedInUser" != "loginwindow" ]; then
    printlog "runAsUser $currentUser: $*"
    uid=$(id -u "$loggedInUser")
    launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"
  fi
}


# ---------------------------------------------------------------------------------------
# Quit a running process
# ---------------------------------------------------------------------------------------
quitApp() {
  printlog "Ending..." ALERT # print function name and arguments
  processStatus=$( /usr/bin/pgrep -x "$process")
  if [ "$processStatus" ]; then
    printlog "Found blocking process $process"
    
    if [ "$DEBUG" -eq 0 ]; then
      printlog "Stopping process $process"
      #runAsUser osascript -e "tell app \"$process\" to quit"
      # pkill "$process"
      printlog "$(killall "$process")"
      # small delay after kill action
      sleep 3
    fi
  else
    printlog "Found no blocking process..."
  fi
}


# ---------------------------------------------------------------------------------------
# Remove file system paths
# ---------------------------------------------------------------------------------------
removeFileDirectory() { # $1: object $2: logmode
  printlog "Arguments: $*" DEBUG # print function name and arguments
    object=${1:-"Object"}
    logmode=${2:-"Log Mode"}
  if [ -f "$object" ]; then
    # file exists and can be removed
    printlog "Removing file $object"
    if [ "$DEBUG" -eq 0 ]; then
      printlog "$(rm -fv "$object")"
    fi
  elif [ -d "$object" ]; then
    # it is not a file, it is a directory and can be removed
    printlog "Removing directory $object..."
    if [ "$DEBUG" -eq 0 ]; then
      printlog "$(rm -Rfv "$object" | cut -d "/" -f1-5 | uniq)" # Reducing path length to reduce logging
    fi
  elif [ -L "$object" ]; then
    # it is an alias
    printlog "Removing alias $object..."
    if [ "$DEBUG" -eq 0 ]; then
      printlog "$(rm -fv "$object")"
    fi
  else
    # it is not a file, alias or a directory. Don't remove.
    if [ "$logmode" != "silent" ]; then
    	printlog "INFO: $object is not an existing file or folder"
    fi
  fi
}


# ---------------------------------------------------------------------------------------
# Remove empty folders
# ---------------------------------------------------------------------------------------
removeEmptyDirectory() { # $1: object $2: logmode
  printlog "Arguments: $*" DEBUG # print function name and arguments
    object=${1:-"Object"}
    logmode=${2:-"Log Mode"}
  if [ -d "$object" ]; then
    # it is a directory
    printlog "Removing empty folder $object..."
    if [ "$DEBUG" -eq 0 ]; then
      printlog "$(rmdir -v "$object")"
    fi
  else
    # it is not a folder. Don't remove.
    if [ "$logmode" != "silent" ]; then
    	printlog "INFO: $object is not an existing folder"
    fi
  fi
}


# ---------------------------------------------------------------------------------------
# Remove Launch Daemons and Agents
# ---------------------------------------------------------------------------------------
removeLaunchDaemons() {
  printlog "Arguments: $*" DEBUG # print function name and arguments
  # remove LaunchDaemon
  if [ -f "$launchDaemon" ]; then
    # LaunchDaemon exists and can be removed
    if [ "$DEBUG" -eq 0 ]; then
      printlog "$(launchctl unload "$launchDaemon")"
      printlog "$(rm -Rfv "$launchDaemon")"
      service_name=$(defaults read "$launchDaemon" Label)
      # unload using modern bootout
      if launchctl print "system/${service_name}" &> /dev/null ; then
        printlog "unloading $launchDaemon"
        launchctl bootout system "$launchDaemon" &> /dev/null
      fi
      printlog "Removing launchDaemon $launchDaemon..."
      /bin/rm -Rf "$launchDaemon"
    fi
  fi
}

removeLaunchAgents() { # $1: object
  printlog "Arguments: $*" DEBUG # print function name and arguments
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
    	printlog "$(rm -Rfv "$object")"
    fi
  fi
}


# ---------------------------------------------------------------------------------------
# Show notification to the user
# ---------------------------------------------------------------------------------------
displayNotification() { # $1: message $2: title
  printlog "Arguments: $*" DEBUG # print function name and arguments
  
  local message=${1:-"Message"}
  local title=${2:-"Notification"}
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
    ws1)
      if [ -x "$hubcli" ]; then
        "$hubcli" -i "$message" -t "$title" -c "Dismiss"
      else
        printlog "ERROR: $hubcli not installed for showing notifications. Falling back to AppleScript"
        FallBacktoAS=true
      fi
    ;;
    swiftdialog)
      if [ -x "$swiftDialog" ]; then
        "$swiftDialog" --message "$message" --title "$title" --$swiftDialogNotification
      else
        printlog "ERROR: $swiftDialog not installed for showing notifications.  Falling back to AppleScript"
        FallBacktoAS=true
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

