#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
declare -i EXIT=0
if [[ $(cat /proc/cmdline) == *privmodetrue* ]];then
    notify-send "Privacy Mode Activated" "The System Hostname And All Ethernet MAC Addresses have been scrambled" --icon=dialog-information --expire-time=10000
    EXIT+=$?
    rm "$HOME/.config/autostart/notify-privmode.desktop"
    EXIT+=$?
    echo "privacy mode activiated"
fi

exit $EXIT
