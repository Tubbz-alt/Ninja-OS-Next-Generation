#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# this script starts the metasploit RPC server. Temp until we can get systemd
# figured out
IP_ADDR=127.0.0.1
PORT=55553

# username and password
RPC_USER=msf
RPC_PASSWORD=test

ACTION="$1"
PID=$(cat /run/msfrpc.pid 2> /dev/null )

help_and_exit() {
cat 1>&2 <<- EOF
metasploit_rpc_server.sh: start and stop metasploit rpc server

	Usage:
	# metasploit_rpc_server.sh [start|stop|status|help]
EOF
}

#The three finger claw
try() {
  $@ || exit_with_error $? "$@ failed"
}
message() {
  echo "$0: $@"
}
exit_with_error() {
  message "ERROR: ${2}" 1>&2
  exit $1
}

metasploit_rpcd() {
BUNDLE_GEMFILE=/opt/metasploit/Gemfile bundle-2.3 exec ruby-2.3 /opt/metasploit/msfrpcd "$@"
}

[ $USER != "root" ] && exit_with_error 1 "script must run as root!"

case $ACTION in
  start)
    systemctl start postgresql
    try metasploit_rpcd  -f -a $IP_ADDR -U $RPC_USER -P $RPC_PASSWORD -S -p $PORT &
    echo $! > /run/msfrpc.pid
    message "Started...($(cat /run/msfrpc.pid))"
    ;;
  stop)
    systemctl stop postgresql
    try kill -9 ${PID} && rm /run/msfrpc.pid
    message "Stopping...(${PID})"
    ;;
  status)
    postgres_active=$(systemctl is-active postgresql)
    message "postgresql db: ${postgres_active}"
    if [ -z $PID ];then
      message "Not Running!"
        else
      message "Running...(${PID})"
    fi
    ;;
   help|*)
   help_and_exit
   ;;
esac
