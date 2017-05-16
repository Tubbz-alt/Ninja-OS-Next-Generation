#!/tmp/emergency_bin/busybox sh
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# Alternative to drive_watch.sh This script runs on a udev "remove" action.
# Does not stay resident.

. /usr/share/scripts/liveos_lib.sh

reboot_now() {
    /tmp/emergency_bin/busybox reboot -f
    /var/emergency_bin/busybox reboot -f
    /usr/bin/reboot -f
    systemctl --force reboot
}

[ ! -b $BOOTDEV ] && reboot_now
