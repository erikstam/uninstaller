#!/bin/zsh --no-rcs

#
# Script for testing uninstaller labels
#
# This script is designed to verify that no leftover files remain after uninstalling applications. 
# It should be run on a test device to ensure accurate results.
#
# Based on the findings, you can modify, update, or improve the uninstaller labels as needed.
#
# The script performs the following steps:
# 1. Parses the labels folder.
# 2. Attempts to install each label using Installomator (installs Installomator if not already present).
# 3. Launches every `.app` specified in the label.
# 4. Uninstalls the app using Installomator.
#
# The script runs interactively and prompts the user before each install/uninstall operation:
# "Do you want to test APPNAME? (Y)es, (N)o, (A)utorun All, e(X)it"
#
# - Choosing (Y) will install and uninstall the app, then prompt again for the next app.
# - Choosing (N) will skip the current app and prompt again for the next app.
# - Choosing (A) will automatically proceed with all remaining apps starting from the current app.
# - Choosing (X) will terminate the script.
#

runAsUser() {
  if [ "$loggedInUser" != "loginwindow" ]; then
    uid=$(id -u "$loggedInUser")
    /bin/launchctl asuser "$uid" sudo -u "$loggedInUser" "$@"
  fi
}

InstallInstallomator() {
	# install installomator
	InstallomatorURL=$(curl -s https://api.github.com/repos/Installomator/Installomator/releases/latest | grep browser_download_url | cut -d'"' -f4)
	echo "$InstallomatorURL"
	curl -s -L -o /tmp/installomator.pkg "$InstallomatorURL"
	installer -pkg /tmp/Installomator.pkg -target /
	rm /tmp/installomator.pkg
}

# check for root
if [ "$(whoami)" != "root" ]; then
  echo "not running as root, exiting"
  exit 1
fi

loggedInUser=$( /usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk '/Name :/ { print $3 }' )
loggedInUserID=$( /usr/bin/id -u "$loggedInUser" )

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Get the directory of the script
script_dir=$(dirname "$0")

# Define the labels folder relative to the script's location
dir="$script_dir/../fragments/labels"
uninstaller="$script_dir/../build/uninstaller.sh"
# Ensure the uninstaller exists
if [[ ! -f $uninstaller ]]; then
  echo "uninstaller build '$uninstaller' does not exist."
  uninstaller="$script_dir/../uninstaller.sh"
  
  if [[ ! -f $uninstaller ]]; then
  echo "uninstaller build '$uninstaller' does not exist."
  exit
  fi
  
  
fi

chmod +x $uninstaller

# Ensure the directory exists
if [[ ! -d $dir ]]; then
  echo "Directory '$dir' does not exist."
  exit 1
fi



# Loop through all .sh files in the directory
autostatus=0
for file in "$dir"/*.sh; do
	# Skip if no .sh files are found
	[[ ! -e $file ]] && continue
	
	filename=$(basename "$file" | sed 's/.sh//g')
	
	tempstatus=0
	if [[ $autostatus == "0" ]]; then
    
		echo "${BLUE}Do you want to test $filename? (Y)es, (N)o, (A)utorun All, e(X)it${NC}"
		read -r answer
	
		case $answer in
			[yY]) 
				tempstatus=1
				;;
			[nN]) 
				tempstatus=0
				;;
			[xX]) 
				echo "Exiting the script."
				exit 0
				;;
			[aA]) 
				 autostatus=1
				;;
			*) 
				echo "Invalid input. Please enter 'y', 'n', 'a' or 'x'."
				;;
		esac
		
		
		
	
	
	fi
	
	if [[ $autostatus == "1" ]] || [[ $tempstatus == "1" ]]; then
		appslaunched=0
	
		echo "----------------------------------------------"
				echo "${GREEN}Installing $filename ${NC}"
				
				if [[ ! -f /usr/local/Installomator/Installomator.sh ]]; then
					InstallInstallomator
				fi
				
				/usr/local/Installomator/Installomator.sh $filename
				echo
				# echo "${YELLOW}Launching apps in $filename ${NC}"
				
				# Array to hold .app file paths
				app_paths=()
				
				# Read the text file line by line
				while IFS= read -r line; do
					# Check if the line contains .app and extract the file path
					if [[ $line =~ \"/.*\.app\" ]]; then
						# Remove surrounding quotes and store in the array
						app_path=$(echo $line | grep -o '".*\.app"' | tr -d '"')
						app_paths+=("$app_path")
					fi
				done < "$file"
					
				# Launch each .app file found
				for app in "${app_paths[@]}"; do
					if [[ -d $app ]]; then
						echo "${YELLOW}Launching $app...${NC}"
						runAsUser open "$app"
						 appslaunched=1
					fi
					sleep 2
				done
				
				echo "${RED}UnInstalling $filename ${NC}"
				if [[ $appslaunched == "1" ]]; then
					sleep 10
				fi
				$uninstaller $filename
				
				echo "----------------------------------------------"
	
	fi
	
	
done


echo "Done!"
