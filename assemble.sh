#!/bin/zsh --no-rcs

#
# Assemble script is highly inspired by / mostlty copied from Installomator
# https://github.com/Installomator/Installomator
#
# 

# Last modification date
LAST_MOD_DATE="2024-03-15"

#setup some folders
repo_dir=$(dirname ${0:A})
build_dir="$repo_dir/build"
destination_file="$build_dir/uninstaller.sh"
fragments_dir="$repo_dir/fragments"
labels_dir="$fragments_dir/labels"

# add default labels_dir to label_paths
label_paths+=$labels_dir

#echo "label_paths: $label_paths"


zparseopts -D -E -a opts r -run s -script h -help -labels+:=label_args l+:=label_args

if (( ${opts[(I)(-h|--help)]} )); then
    echo "usage: assemble.sh [--script]"
    echo
    echo "Builds and runs the uninstaller script from the fragments."
    echo 
    echo "When --script is used the uninstaller script in the root of the project will be replaced. And labels.txt will be updated."
    echo "Otherwise the uninstaller script will be built in the /built directory."
    exit
fi

# Default Settings
runScript=1

if (( ${opts[(I)(-s|--script)]} )); then
    buildScript=1
fi

fragment_files=( header.sh version.sh functions.sh arguments.sh main.sh )

# check if fragment files exist (and are readable)
for fragment in $fragment_files; do
    if [[ ! -e $fragments_dir/$fragment ]]; then
        echo "# $fragments_dir/$fragment not found!"
        exit 1
    fi
done

if [[ ! -d $labels_dir ]]; then
    echo "# $labels_dir not found!"
    exit 1
fi

# create $build_dir when necessary
mkdir -p $build_dir

# add the header
cat "$fragments_dir/header.sh" > $destination_file

# add the version and builddate
cat "$fragments_dir/version.sh" >> $destination_file
currentdate=$(date)
echo "BUILD_DATE=\"$currentdate\"\n" >> $destination_file

# add the functions
cat "$fragments_dir/functions.sh" >> $destination_file

# add the arguments
cat "$fragments_dir/arguments.sh" >> $destination_file

# all the labels
for lpath in $label_paths; do
    if [[ -d $lpath ]]; then
        cat "$lpath"/*.sh >> $destination_file
    else
        echo "# $lpath not a directory, skipping..."
    fi
done

# add the footer
cat "$fragments_dir/main.sh" >> $destination_file

# set the executable bit
chmod +x $destination_file

# run script with remaining arguments
if [[ $runScript -eq 1 ]]; then
    $destination_file "$@"
    exit_code=$?
fi

# copy the script to root of repo when flag is set
if [[ $buildScript -eq 1 ]]; then
    echo "# copying script to $repo_dir/uninstaller.sh"
    cp $destination_file $repo_dir/uninstaller.sh
    chmod 755 $repo_dir/uninstaller.sh
    # also update Labels.txt
    $repo_dir/uninstaller.sh | tail -n +2 > $repo_dir/Labels.txt
fi

exit $exit_code
