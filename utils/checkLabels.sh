#!/bin/zsh --no-rcs

#
# Script to check all labels and print the filenames of those that fail the checks
#
# checks:
# 1) label must exactly end with ;; followed by a newline (ERROR)
# 2) every line in label is unique (WARNING)
#

countError=0
countWarnings=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Get the directory of the script
script_dir=$(dirname "$0")

# Define the labels folder relative to the script's location
dir="$script_dir/../fragments/labels"

# Ensure the directory exists
if [[ ! -d $dir ]]; then
  echo "Directory '$dir' does not exist."
  exit 1
fi

uninstallerlabelcountfiles=$(ls -l "$dir" | tail -n +2 | wc -l | sed 's/ //g')


# Loop through all .sh files in the directory
for file in "$dir"/*.sh; do
  # Skip if no .sh files are found
  [[ ! -e $file ]] && continue
  
  filename=$(basename "$file")

  # Check if the file ends with an exact ;; and newline
  # Last chars of label as ASCI
  last_char=$(tail -c 3 "$file" | od -An -tuC | sed 's/ //g')
  if [[ $last_char != "595910" ]] ; then
    echo "${RED}label $filename does not correctly end with only ;; and newline${NC}"
    ((countError++))
  else
    echo "${GREEN}label $filename looks OK${NC}"
  fi
  
  # Check for duplicate lines in label 
  duplicateLines=$(sort "$file" | uniq -d | wc -l | sed 's/ //g')
  if [[ $duplicateLines != "0" ]] ; then
    echo "${YELLOW}label $filename contains duplicate lines${NC}"
    ((countWarnings++))
  else
    echo "${GREEN}label $filename looks OK${NC}"
  fi
  
  
  
done

echo "\n${BLUE}Total labels:${NC} ${uninstallerlabelcountfiles}"
if [[ countError -gt 0 ]]; then
    echo "${RED}ERRORS counted: $countError${NC}"
else
    echo "${GREEN}No errors detected!${NC}"
fi
if [[ countWarnings -gt 0 ]]; then
    echo "${YELLOW}WARNINGS counted: $countWarnings${NC}"
else
    echo "${GREEN}No warnings detected!${NC}"
fi




echo "Done!"
