#!/bin/sh
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#This script calls mh_scramble --rescramble in addition to informing the GUI what is going on. We decided to keep notify-send command out of mh_scramble.sh
notify-send "Generating a New Random Hostname and New Random Ethernet MAC Addresses" "Wait for the screen to finish reseting itself" --icon=network-transmit-receive --expire-time=15000
sudo /usr/share/scripts/mh_scramble.py --rescramble

exit $?
