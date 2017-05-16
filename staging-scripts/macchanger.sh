#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# most simple script evar. This is a direct replacement for the "macchanger"
# binary, which's entire functionality can be accomplished in 5 lines of bash.

help_and_exit() {
cat 1>&2 << EOF
macchanger.sh: Change the MAC address of an interface

	Usage:
	macchanger.sh <interface> <new mac address>

EOF
exit 1
}
[[ $@ == *help* ]] && help_and_exit

# Five lines of motherfucken bash.
IFACE="$1"
NEWMAC="$2"
ifconfig hw ether ${IFACE} down
ifconfig hw ether ${IFACE} ${NEWMAC}
ifconfig hw ether ${IFACE} up
