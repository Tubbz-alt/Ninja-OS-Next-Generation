#!/bin/bash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script will enable or disable iptables rules. They are enabled by default
#case insensative $1
ACTION=${1,,}
declare -i EXIT="0"

notify_iptables_status(){
  #returns active for working, inactive for not working
  local status="$(systemctl is-active iptables)"
  case $status in
   active)
    notify-send "Firewall Status: Enabled" "IPtables firewall rules are loaded" --icon=security-high
    echo "status: enabled"
    return 0
    ;;
   inactive)
    notify-send "Firewall Status: Disabled" "IPtables firewall rules have been previously cleared" --icon=security-low
    echo "status: disabled"
    return 0
    ;;
   unknown)
    notify-send "Firewall Status: ERROR" "Cannot find iptables unit" --icon=error
    echo "status: unit_error"
    return 1
    ;;
   *)
    notify-send "Firewall Status: Unexpected ERROR" "Something has gone terribly wrong, please check iptables and systemctl manually" --icon=error
    echo "status: systemd_error"
    return 1
    ;;
  esac
}

help_and_exit() {
  echo "$(tput bold)firewall_gui_control.sh:$(tput sgr0)" 1>&2
  cat 1>&2 << EOF
This script wraps enabling and disabling of IPTables firewall rules for the gui,
using libnotify.

	USAGE:
/usr/share/scripts/firewall_gui_control.sh [start|stop|status]

EOF
exit 1
}

case $ACTION in
 start)
  sudo systemctl start iptables
  EXIT=$?
  notify-send "Enabling Firewall" "Loading IPtables firewall rules" --icon=security-high
  echo "starting..."
  ;;
 stop)
  sudo systemctl stop iptables
  EXIT=$?
  notify-send "Disabling Firewall" "Clearing IPtables firewall rules" --icon=security-low
  echo "stopping..."
  ;;
 status)
  notify_iptables_status
  EXIT=$?
  ;;
 *)
  help_and_exit
  ;;
esac

if [[ $EXIT -ne 0 ]];then
  echo "${0}: Script threw a code somewhere $(tput bold;tput setaf 1)!FAIL!$(tput sgr0)" 1>&2
  notify-send "Firewall Control FAIL!" "Last Action failed Exit code: ${EXIT}"
fi
exit ${EXIT}
