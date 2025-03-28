*) # if no specified event/label is triggered, do nothing
      printlog "ERROR: Unknown label: $label"
      exit 1
      ;;
esac

printlog "Uninstaller started - build $BUILD_DATE"

# Parse arguments for changed variables
while [[ -n $1 ]]; do
    if [[ $1 =~ ".*\=.*" ]]; then
        # if an argument contains an = character, send it to eval
        printlog "setting variable from argument $1"
        eval $1
    fi
    # shift to next argument
    shift 1
done

# Get app version
if [ -f "${appFiles[1]}/Contents/Info.plist" ]; then
	appVersion=$(defaults read "${appFiles[1]}/Contents/Info.plist" $appVersionKey)
	appBundleIdentifier=$(defaults read "${appFiles[1]}/Contents/Info.plist" $appBundleIdentifierKey)
fi    

if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
	displayNotification "Starting to uninstall $appTitle $appVersion..." "Uninstalling $appTitle"
fi

# Running preflight commands
printlog "$appTitle - Running preflightCommand"
for precommand in "${preflightCommand[@]}"
do
    if [ "$DEBUG" -eq 0 ]; then
      	zsh -c "$precommand"
    fi
done


# Remove LaunchDaemons
printlog "Uninstalling $appTitle - LaunchDaemons"
if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
  displayNotification "Removing LaunchDaemons..." "Uninstalling in progress"
fi

for launchDaemon in "${appLaunchDaemons[@]}"
do
	removeLaunchDaemons
done


# Remove LaunchAgents
printlog "Uninstalling $appTitle - LaunchAgents"
if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
  displayNotification "Removing LaunchAgents..." "Uninstalling in progress"
fi
for launchAgent in "${appLaunchAgents[@]}"
do
	if [[ "$launchAgent" == *"<<Users>>"* ]]; then
		# remove launchAgent with expanded path
		for userfolder in $(ls /Users)
		do
			expandedPath=$(echo $launchAgent | sed "s|<<Users>>|/Users/$userfolder|g")
			removeLaunchAgents "$expandedPath"
		done
	else
		# remove path without 
		removeLaunchAgents "$launchAgent"
	fi
done


# Stop app appProcesses
printlog "Checking for blocking processes..."
if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
	displayNotification "Quitting $appTitle..." "Uninstalling in progress"
fi
if [ -n "${appProcesses[1]}" ]; then
	for process in "${appProcesses[@]}"
	do
	  quitApp
	done
else
	# use $appTitle if no separate appProcesses are defined
	process="$appTitle"
	quitApp
fi


# Remove Files and Directories
printlog "Uninstalling $appTitle - Files and Directories"
if [[ $loggedInUser != "loginwindow" && $NOTIFY == "all" ]]; then
	displayNotification "Removing $appTitle files..." "Uninstalling in progress"
fi
# Change the first object of $appFiles, if $ALTERNATIVE_PATH is added as an argumet
if [[ $ALTERNATIVE_PATH ]]; then
	appFiles[1]="$ALTERNATIVE_PATH"
fi
for file in "${appFiles[@]}"
do
	if [[ "$file" == *"<<Users>>"* ]]; then
		if [[ $IGNORE_USER_DIRS == 0 ]]; then
			# remove path with expanded path for all available userfolders
			for userfolder in $(ls /Users)
				do
					expandedPath=$(echo $file | sed "s|<<Users>>|/Users/$userfolder|g")
					removeFileDirectory "$expandedPath" silent
			done
		else
			printlog "Ignoring deletion of user files: $file" 
		fi
	else
		# remove real path 
		removeFileDirectory "$file"
	fi
done


# Running postflight commands
printlog "Running $appTitle - postflightCommand" 
for postcommand in "${postflightCommand[@]}"
do
    if [ "$DEBUG" -eq 0 ]; then
      	zsh -c "$postcommand"
    fi
done


if [ -n "$appBundleIdentifier" ]; then
	printlog "Checking for receipt.."
	receipts=$(pkgutil --pkgs | grep -c "$appBundleIdentifier")
	if [[ "$receipts" != "0" ]]; then
	    if [ "$DEBUG" -eq 0 ]; then
      		/usr/sbin/pkgutil --forget "$appBundleIdentifier"
    	fi	
	fi
fi


# Remove manual receipts
if [ -n "${appReceipts[1]}" ]; then
	printlog "Removing $appTitle receipts" 
	for receipt in "${appReceipts[@]}"
	do
		if [ "$DEBUG" -eq 0 ]; then
      		/usr/sbin/pkgutil --forget "$receipt"
    	fi	
	done
fi


# restart prefsd to ensure caches are cleared
/usr/bin/killall -q cfprefsd

if [[ $loggedInUser != "loginwindow" && ( $NOTIFY == "success" || $NOTIFY == "all" ) ]]; then
	displayNotification "$appTitle is uninstalled." "Uninstalling completed!"
fi
printlog "Uninstaller Finished"

