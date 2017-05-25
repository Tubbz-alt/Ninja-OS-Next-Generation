#!/bin/bash

# Count $X_PRESS amount of presses in $TICK seconds before activating
# self destruct. Link this script to an X11 keypress

X_PRESS=3
TICK=0.8

SCRIPT_NAME=$(basename $0)
COUNT=$(ps aux|grep ${SCRIPT_NAME}|wc -l)
COUNT=$(( ${COUNT} - 1 ))

#notify-send "${COUNT}" "Count to ${X_PRESS} to activate"
cat 2>&1 << EOF
This script is designed to be called from a button or shortcut key press.
It will destroy the system by invoking liveos_sd.sh --noconfirm It will only
run if you run it $X_PRESS times in $TICK seconds. see reboot_nuke.sh for 
more information.

EOF
sleep $TICK
[ "${COUNT}" -gt "${X_PRESS}" ] && /usr/share/scripts/liveos_sd.sh --noconfirm
