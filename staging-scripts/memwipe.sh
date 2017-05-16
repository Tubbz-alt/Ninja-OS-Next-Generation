#!/bin/sh
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# Wipes memory on shutdown, disabled for now because the system hangs when memory is full.

dead_mans_switch() {
    sleep 10
    exit 1
}
dead_mans_switch &

mkdir /tempwipe
/tmp/emergency_bin/busyboxmount -t tmpfs -o size=99%,noatime,nodiratime tmpfs /tempwipe
/tmp/emergency_bin/busybox dd if=/dev/zero of=/tempwipe/fillfile bs=128k
/tmp/emergency_bin/busybox sync
/tmp/emergency_bin/busybox umount -f /tempwipe
exit 0
