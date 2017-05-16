#!/bin/bash
. /usr/share/scripts/liveos_lib.sh
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script is a front end to dd to easily make a Ninja OS USB stick from
# .img files. It requires the stick be formated correctly for Ninja OS with
# Ninja Forge. This script can be used as a stand alone for upgrades.

#Define filenames
TARGET=""
MAINIMG="${OSSLUG}_${OSVERSION}.img"
BOOTSECTOR="ninjabootsector${OSVERSION}.img"
declare -i P=1 # ${P} is disk parition number, i.e. /dev/sdX1

help_and_exit() {
  echo "${BRIGHT}makeninja.sh:${NOCOLOR}" 1>&2
cat 1>&2 << EOF
	This script copies a Ninja OS .img file and bootloader to the specified
drive. The drive needs to be partitioned correctly by ninjaforge.sh first in
order to work. Running this script dirrectly is useful for upgrades where you
don't want to loose any data on the rest of the drive. Please note when
upgrading to make sure that partition 1 is the correct size. Make sure the
value in liveos_version.conf matches what is on the disk. to set up partitioning
see ninjaforge.sh. A block device is the name of the HDD/SSD i.e. /dev/sda

	Usage:
	makeninja.sh [--switches] <block device>

	Options:
	-?, --help	This message.

	-p, --part-num	Disk Partition Number. Default is 1. i.e. as /dev/sda1

EOF
exit 1
}

# exit with an error message. $1 is exit status, $2 is message, be sure to have
# "$2" in quotes.
exit_with_error() {
  echo "${BRIGHT}makeninja.sh:${BRIGHT_RED} ERROR:${NOCOLOR} $2" 1>&2
  exit $1
}

message() {
  echo "${BRIGHT}makeninja.sh:${NOCOLOR} ${@}"
}
submsg() {
    echo "	${@}"
}

switch_checker() {
    PARMS=""
    while [ ! -z "$1" ];do
        case "$1" in
          --help|-\?)
            help_and_exit
            ;;
          --part-num|-p)
            [ -z $2 ] && exit_with_error 1 "when using -p you need to specify a number, see --help"
            [ "$2" -eq "$2" 2> /dev/null ] && p=$2
            shift
            ;;
          *)
            PARMS+="$1"
            ;;
        esac
        shift
    done
}

main() {
    trap "exit_with_error 1 'Aborted!' " SIGINT SIGTERM #exit cleanly with an abort
    # Basic input checking
    TARGET="$1"
    [ -z ${TARGET} ] && help_and_exit
    #Sanity check on inputs.
    if [[ ! -f "${MAINIMG}" ]];then
        exit_with_error 1 "${MAINIMG} not found in local directory, aborting..."
      elif [[ ! -f "${BOOTSECTOR}" ]];then
        exit_with_error 1 "${BOOTSECTOR} not found in local directory, aborting..."
      elif [[ ! -b ${TARGET} ]];then
        exit_with_error 1 "${TARGET} is not a block device, exiting..."
    fi

    # lets ask a sudo password now, rather than later. if we need a password,
    # sudo should cache it so the script runs uninterrupted later.
    [ $(check_sudo) != "TRUE" ] && exit_with_error 1 "Cannot get root with sudo, aborting..."

    ##Here is where we start to do the copy. NOTE: ${P} is the parition number
    # start with the main image. if we can find "pv" on the system we use it for a
    # status bar.
    message "Copying (${BRIGHT}${OSNAME} ${OSVERSION}${NOCOLOR}) system data to ${BRIGHT_YELLOW}${TARGET}${NOCOLOR}. Be patient this might take a while..."
    #Main partition
    submsg "${BRIGHT_GREEN}${MAINIMG}${NOCOLOR} -> ${BRIGHT_YELLOW}${TARGET}${P}${NOCOLOR}:"
    if [ -f $(which pv) ];then
        dd if="${MAINIMG}" bs=128k 2> /dev/null | pv -B 128k -s ${PART_SIZE}m | sudo dd of=${TARGET}${P} bs=128k &> /dev/null
        [ $? -ne 0 ] && exit_with_error 1 "Operating System image copy failed!"
      else
        sudo dd if="${MAINIMG}" of=${TARGET}${P} bs=128k status=progress
        [ $? -ne 0 ] && exit_with_error 1 "Operating System image copy failed!"
    fi

    # Hack to make sure that kernels 3.6.0 and later in conjunction with a auto
    # mount tendencies don't leave the disk mounted before we write the boot sector.
    # this results in a corrupt disk.
    #sudo umount ${TARGET}* &> /dev/null

    #Now we make the bootsector
    submsg "${BRIGHT_GREEN}${BOOTSECTOR}${NOCOLOR} -> ${BRIGHT_YELLOW}${TARGET}${NOCOLOR}:"
    if [ -f $(which pv) ];then
        sudo dd if="${BOOTSECTOR}" bs=440 count=1 2> /dev/null | pv -s 440 | sudo dd of="${TARGET}" bs=440 count=1 &> /dev/null
        [ $? -ne 0 ] && exit_with_error 1 "Bootsector installation failed!"
      else
        sudo dd if="${BOOTSECTOR}" of="${TARGET}" bs=440 count=1 status=progress
        [ $? -ne 0 ] && exit_with_error 1 "Bootsector installation failed!"
    fi

    #Sync to make sure the disk physically writes
    sync
    echo "${BRIGHT_CYAN}DONE!${NOCOLOR}"
}
switch_checker "${@}"
main ${PARMS}
