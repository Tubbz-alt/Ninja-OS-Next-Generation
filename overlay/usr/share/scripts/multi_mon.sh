#!/bin/bash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script automatically sets up multiple monitors correctly with xrandr.
# XFCE won't do it.

#Get a list and count of the number of attached monitors
MonList=( $(xrandr |grep " connected"|cut -d " " -f 1) )
MonCount=${#MonList[@]}
declare -i EXIT=0

# Now for every monitor we set in a predermined location. There is no way we can
# actually sense how monitors are physically set up in relation to eachother,
# so we just guess.
echo "Found $(tput bold)${MonCount}$(tput sgr0) monitors. Repositioning..."

case $MonCount in
  0)  #If no monitors are found, do nothing, and fail with an error code.
    echo "	No Monitors Detected!"
    EXIT+=1
    ;;

  1)  #Only one monitor, does nothing.
    echo "	Only one monitor, nothing to do."
    ;;

  2)  #Two Monitors - We assume they are side by side, with monitor 1 being on the left.
    xrandr --output ${MonList[1]} --right-of ${MonList[0]}
    EXIT+=$?
    echo "	Two Monitors Found, Left and Right."
    ;;

  3)  #Three Monitors - If there are three monitors, we assume they are left to right, in order.
    xrandr --output ${MonList[1]} --right-of ${MonList[0]}
    EXIT+=$?
    xrandr --output ${MonList[2]} --right-of ${MonList[1]}
    EXIT+=$?
    echo "	Three Monitors Found, Three in a row"
    ;;

  4|*)  #Four+ Monitors - For Four or more monitors, we assume they are aligning in a two by two square.
    xrandr --output ${MonList[1]} --right-of ${MonList[0]}
    EXIT+=$?
    xrandr --output ${MonList[2]} --above ${MonList[0]}
    EXIT+=$?
    xrandr --output ${MonList[3]} --right-of ${MonList[2]}
    EXIT+=$?
    echo "	Four or more monitors found - assume a 2x2 square"
    ;;

esac
#Exit gracefully with the exit code being total amount of errors.
exit $EXIT
