#!/bin/bash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script will start or stop the service for the I2P(invisible internet
# Project) daemon. It can also launch a console

ACTION=${1,,}
I2P_CONSOLE="http://localhost:7657"
declare -i EXIT=0

notify_i2p_status(){
    #returns active for working, inactive for not working
    local status="$(systemctl is-active i2prouter)"
    case $status in
      active)
        notify-send "I2P Router: Running" "You are connecting/connected to the Invisible Internet" --icon=i2p-start
        echo "status: enabled"
        return 0
        ;;
      inactive|unknown)
        notify-send "I2P Router: Stopped!" "You are not connected to the Invisible Internet" --icon=i2p-stop
        echo "status: disabled"
        return 0
        ;;
      *)
        notify-send "I2P Router: Unexpected ERROR" "Something has gone terribly wrong, please check i2prouter and systemctl manually" --icon=i2p-error
        echo "status: systemd_error"
        return 1
        ;;
    esac
}

help_and_exit() {
    echo "$(tput bold)i2p_control.sh:$(tput sgr0)" 1>&2
    cat 1>&2 << EOF
This script is a freedesktop menu wrapper for starting and stopping the
i2prouter service, as well as checking status. console will open the web console

	USAGE:
/usr/share/scripts/i2p_control.sh [start|stop|console|status]

EOF
exit 1
}

case $ACTION in
    start)
      sudo systemctl start i2prouter
      EXIT=$?
      notify-send "Starting I2P" "Connecting to Invisible Internet" --icon=i2p-start
      echo "starting"
      ;;
    stop)
      sudo systemctl stop i2prouter
      EXIT=$?
      notify-send "Stoping I2P" "Disconnected from the Invisible Internet" --icon=i2p-stop
      echo "stopping"
      ;;
    status)
      notify_i2p_status
      EXIT=$?
      ;;
    console)
      xdg-open "$I2P_CONSOLE"
      EXIT=$?
      ;;
    *)
      help_and_exit
      ;;
esac

if [[ $EXIT -ne 0 ]];then
    echo "i2p_control.sh: Script threw a code, previous action failed" 1>&2
    notify-send "I2P Router: FAIL!" "Last Action Failed, exit code: $EXIT" --icon=i2p-error
fi
exit ${EXIT}
