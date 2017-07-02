#!/bin/bash
. /usr/share/scripts/liveos_lib.sh
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script runs at start up, stays resident and watches for the OS drive to
# be unplugged. If so it shuts the system down.

TICK=".3333"

tamper_reboot() {
    # This function reboots the machine if tampering is found with any of
    # components. We try a few shutdown methods until one sticks
    notify-send "Tampering Detected" "Rebooting..." --icon=software-update-urgent
    echo "Tampering Detected, Rebooting"
    sleep $(bc <<< "$TICK * 3 ")
    /tmp/emergency_bin/busybox reboot -f &
    /var/emergency_bin/busybox reboot -f &
    /usr/bin/reboot -f &
    systemctl --force reboot &
}

tamper_check() {
    # This function checks if any of the binaries needed for emergency actions
    # are tampered with. busybox is needed for this script, and pv is needed for
    # zeroize.
    [ -f /tmp/emergency_bin/busybox ] || tamper_reboot
    [ -f /var/emergency_bin/busybox ] || tamper_reboot
    [ -f /var/emergency_bin/pv ] || tamper_reboot
}
shutdown_check() {
    # If this script is killed by shutdown, regardless, it will reboot the system
    # Therefor the shutdown command will reboot. The solution is to check for
    # shutdown status before checking for tampering.
    local lines_reboot=$(systemctl list-jobs reboot.target|wc -l)
    local lines_poweroff=$(systemctl list-jobs shutdown.target|wc -l)

    [ "${lines_reboot}" -gt "1" ] && reboot -f
    [ "${lines_poweroff}" -gt "1" ] && poweroff -f
}

tamper_kill(){
    # This function runs if we get an interreupt, i.e. someone tries to kill
    # poor mr tamper check.
    shutdown_check
    tamper_reboot
}

# If someone tries to disrupt the script while running, reboot.
trap "tamper_kill" 1 2 9 15 17 19 23
#adjusting the priority of this script so it doesn't get interrupted.
renice -10 $$ &> /dev/null

while [ -b $BOOTDEV ];do
     # lets check if the system is shutting down, if do the correct action.
     shutdown_check
     # Every tick we check if the system has been tampered with
     tamper_check
     /tmp/emergency_bin/busybox sleep ${TICK}
done

#one final shutdown check in case we are killed by systemd on a shutdown.
shutdown_check
#reboot the system.
/tmp/emergency_bin/busybox reboot -f
