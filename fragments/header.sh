#!/bin/zsh --no-rcs
# shellcheck shell=bash # zsh differences
# shellcheck disable=SC2086,SC2068,SC2120 #,SC2001,SC1112,SC2143,SC2145,SC2089,SC2090,SC2270
# shellcheck disable=SC1111,SC1112,SC2206,SC2296,SC1058,SC1063,SC1072,SC1073


###################################### N A M E ##########################################
## MARK: Uninstaller script built on label recepies                                    ##
scriptName=uninstaller                                                                 ##
############################### D E S C R I P T I O N ###################################
##                                                                                     ##
## Removes software and related files                                                  ##
##                                                                                     ##
## https://github.com/erikstam/uninstaller                                             ##
##                                                                                     ##
#########################################################################################


#########################################################################################
# Self-Service Description for app-only uninstallation (supports markdown)
#########################################################################################
<< SELF_SERVICE.MD
## Will remove APPLICATION from the Mac

App with CLI and other tools will be removed.

**Only app and binaries (and links) is removed no other user data.**
SELF_SERVICE.MD
#########################################################################################
# Self-Service Description for app and user data removal (supports markdown)
#########################################################################################
<< SELF_SERVICE.MD
## Will remove APPLICATION from the Mac

**Fully removes app with user data folders.**
SELF_SERVICE.MD
#########################################################################################


# ***************************************************************************************
# REVIEW: Variables
# ***************************************************************************************

# set to 0 for production, 1 for debugging
# no actual uninstallation will be performed
DEBUG=0 # [0|1] Should we run in DEBUG mode with no changes?

# notify behavior
NOTIFY=success ## [success|silent|all] How many notifications?
# options:
#   - success      notify the user on success
#   - silent       no notifications
#   - all          all notifications (great for Self Service installation)

# notification type
NOTIFICATIONTYPE=swiftdialog # [jamf|swiftdialog|applescript] Which binary for notifications?
# options:
#   - jamf				show notifications using the jamf Management Action binary
#   - ws1               show notifications using the Workspace ONE hubcli binary
#   - swiftdialog       show notifications using swiftdialog
#   - applescript       show notifications using applescript

# Notification Sources
jamfManagementAction="/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action"
hubcli="/usr/local/bin/hubcli"
swiftDialog="/usr/local/bin/dialog"
swiftDialogNotification=mini

# - appVersionKey: (optional)
#   How we get version number from app. Default value
#     - CFBundleShortVersionString
#   other values
#     - CFBundleVersion
appVersionKey="CFBundleShortVersionString"
appBundleIdentifierKey="CFBundleIdentifier"

# ignore deletion of files in user directories
IGNORE_USER_DIRS=1 ## [0 false | 1 true (default)] Should the script ignore the home folder directories?
# options:
# 0            delete files/directories in user directories
# 1            ignore deletion of files in user directories, with exception of LaunchAgents

# Logging
logLocation="/private/var/log/uninstaller.log"

# PATH declaration
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

REMOVEBYHOSTFILES=1
# options:
# 0            do not remove ByHost preference files
# 1            automatically remove UUID-suffixed ByHost variants
