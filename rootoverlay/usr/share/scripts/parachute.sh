#!/bin/bash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#  This script is called by systemd at start sets up the emergency shutdown
# scripts and binaries in /tmp
#
# Create the "emergency parachute". This script copies a staticly compiled
# version of busybox to a RAM based tmpfs parition on /tmp. If the boot disk is
# unexpectedly removed while still running, both script and binary can still
# operate. used with panic_shutdown.sh and drive_watch.sh to reboot the system
# if the boot drive is suddenly pulled. This script works in conjunction with
# self destruct/zeroize and drive_watch.sh

# Lets make our emergency parachute with our specially compiled stripped down
# version of busybox
mkdir /tmp/emergency_bin
cp /var/emergency_bin/busybox /tmp/emergency_bin/
# This is done at boot time, instead of install time because it puts the file in
# the top AUFS layer which is tmpfs which is in ram, which does not go away with
# the boot media is removed.
chmod 555 /tmp/emergency_bin/busybox

