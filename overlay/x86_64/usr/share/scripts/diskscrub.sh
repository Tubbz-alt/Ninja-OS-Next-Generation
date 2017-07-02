#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# Block device shredder. use as diskscrub.sh [options] <device>
# See diskscrub.sh --help
# uses hdparm, pv, sudo, dd, and sfdisk.

### -   Config   - ###
# Source of random characters
RANDSRC=/dev/urandom

# Source of "zeros" or null byte 0x00
ZEROSRC=/dev/zero

## Default options
# Amount of times to overwrite the disk
PASSES=2

# The pattern to use when overwriting the disk. valid options: zerofill, random,
# nnsa, schneier, and none
PATTERN="zerofill"

# Use SATA security wipe command? true or false
SECURE_ERASE="false"

# config in an external file?
# [ -f /etc/diskscrub.conf ] && source /etc/diskscrub.conf
### - End Config - ###

#pretty terminal colors
BRIGHT_RED=$(tput setaf 1;tput bold)
BRIGHT_GREEN=$(tput setaf 2;tput bold)
BRIGHT_YELLOW=$(tput setaf 3;tput bold)
BRIGHT_CYAN=$(tput setaf 6;tput bold)
BRIGHT=$(tput bold)
NOCOLOR=$(tput sgr0)

# This subroutine scrubs recovery data off Solid State Drives.
# parameter $1 is the block device name(/dev/sdX) and $2 is an optional password
# based off: https://wiki.archlinux.org/index.php/SSD_Memory_Cell_Clearing
ssd_secure_erase() {
    local -i exit=0
    # lets get parameters
    local disk=$1
    local password="$2"
    [ -z "$2" ] && password="p4ssw0rd"
    local rtime=$(sudo hdparm -I ${disk}|grep SECURITY\ ERASE\ UNIT| cut -d \  -f 1)
    exit+=$?
    local etime=$(sudo hdparm -I ${disk}|grep SECURITY\ ERASE\ UNIT| cut -d \  -f 6)
    exit+=$?
    message "Attemping ATA Secure Erase of ${disk}"
    # sets a temporary password, which will be overwritten anyway in the wipe
    sudo hdparm --user-master u --security-set-pass "${password}" ${disk}
    exit+=$?
    # do the wipe
    submsg "Using ATA Secure Erase on: ${BRIGHT_YELLOW}${disk}${NOCOLOR}"
    submsg "This should take around ${BRIGHT_GREEN}${etime}${NOCOLOR}, be patient"
    sudo hdparm --user-master u --security-erase-enhanced "${password}" ${disk}
    exit+=$?        
    return $exit
}
check_security_wipe(){
    # check if we can use ATA secure erase on the disk. $1 is the disk name.
    # This script returns "OK" if all tests pass, or prints an error message if
    # we cannot.
    local disk=$1
    local frozen=$(sudo hdparm -I ${disk} 2> /dev/null | grep -i "frozen" &> /dev/null )
    local support=$(sudo hdparm -I ${disk} 2> /dev/null |grep "SECURITY ERASE UNIT" &> /dev/null )
    if [ "${frozen}" != "	not	frozen" ];then
      echo "${disk} is frozen, unfreeze and try again."
    elif [ -z ${support} ];then
      echo "${disk} does not support ATA secure erase, skipping wipe..."
    elif [ ! -b ${disk} ];then
      echo "${disk} is not a block device, cannot ATA secure erase!"
    else
      echo "OK"
    fi
}

#fills target with data, first parameter is the block device, second the pattern
# either "random" or "zerofill"
disk_fill() {
    local disk="$1"
    local pattern="$2"
    local fillsrc="$ZEROSRC"
    local -i exit=0
    local disk_size=$(sudo sfdisk -s "${disk}")
    exit+=$?
    case $pattern in
      zerofill)
        fillsrc="${ZEROSRC}"
        ;;
      onefill)
        echo "onefill not implemented yet"
        return 1
        ;;
      random)
        fillsrc="${RANDSRC}"
        ;;
      *)
        submsg "Bad pattern ${pattern}"
        return 1
        ;;
    esac
    echo "${PATTERN}:"
    dd if="${fillsrc}" bs=128k 2> /dev/null| pv -pbr -B 128k -s ${disk_size}k | sudo dd of="${disk}" bs=128k &> /dev/null
    exit+=$?
    sync
    return $exit
}

check_sudo() {
    # test should equal "root"
    local test=""
    test=$(sudo whoami 2> /dev/null )
    if [ ${test} == "root" ];then
        echo "TRUE"
      else
        echo "FALSE"
    fi
}

# error handling subroutine, first parameter is the exit code, second is the
# message. Be sure to put the message in "quotes"
exit_with_error(){
    message " ${BRIGHT_RED}!ERROR!${NOCOLOR} ${2}" 1>&2
    exit $1
}
try(){
    "${@}" || exit_with_error $? "cannot ${@}";
}

message() {
    echo "${BRIGHT}diskscrub.sh${NOCOLOR}: ${@}"
}
submsg(){
    echo "	      ${@}"
}

help_and_exit() {
    echo "${BRIGHT}diskscrub.sh:${NOCOLOR}" 1>&2
    cat 1>&2 << EOF
This shell script securely wipes data off of disk and flash drives. Defaults to
two passes of zerofill followed up by a SATA hdparm backup data wipe.
Usage: diskscrub.sh [options] <device file>

	Options:

	-p, --pattern	The technique to use, defaults to "zerofill"

	-n, --passes	When using "random" or "zerofill" patterns, you can
			Specify the amount of passes to use. Default is 2

	-s, --security	clear memory cells with the SATA secure erase command
			when done with the wiping

	Patterns:

	zerofill	Fills the disk with zeros (ASCII nullbytes or 0x00) N
			amount of times. N can either be specified by -n or
			defaults to 2.

	random		Fills the disk with randomly generated characters N
			amount of times. N can either be speficied by -n or
			defaults to 2.

	none		Does not scrub by filling. Usefull if you only want to
			use the --security option, and simply SATA command erase

        	-NOT IMPLEMENTED YET-

	nnsa		4-pass NNSA Policy Letter NAP-14.1-C. 2x Random fill,
			1 zerofill, Verify

	schneier	7 pass method described by Bruce Schnieier, modified.
			5x Random Fill, One(0xFF)Fill, and One Zero Fill 

EOF
exit 1
}

switch_checker() {
    PARMS=""
    while [ ! -z "$1" ];do
        case "$1" in
          --help|-\?)
              help_and_exit
              ;;
          --pattern|-p)
              [ -z $2 ] && exit_with_error 1 "No pattern specified with -p, see --help"
              PATTERN="${2,,}"
              shift
              ;;
          --passes|-n)
              [ -z $2 ] && exit_with_error 1 "when using -n you need to specify a number, see --help"
              [ "$2" -eq "$2" 2> /dev/null ] && PASSES=$2
              shift
              ;;
          --security|-s)
              SECURE_ERASE="true"
              ;;
          *)
              PARMS="${PARMS} $1"
              ;;
        esac
        shift
    done
}

main() {
    trap "exit_with_error 1 'Aborted!' " SIGINT SIGTERM #exit cleanly with an abort
    [ -z "$1" ] && help_and_exit
    [ -b "$1" ] || exit_with_error 1 "$1 is not a block device! See diskscrub.sh --help for more information"
    DISK="$1"
    DISK_SIZE=$(sudo sfdisk -l "${DISK}"|head -1|cut -d " " -f 3-4|sed 's/,//m')
    #make sure text parameters are lower case so they match tests.
    SECURE_ERASE="${SECURE_ERASE,,}"; PATTERN="${PATTERN,,}"
    
    #check if we can sudo, this also caches the sudo passwd.
    [ $(check_sudo) != "TRUE" ] && exit_with_error 1 "Cannot get root with sudo"
    #each pattern is done diffrently, lets use a switch statement.
    message "Found device ${BRIGHT_YELLOW}${DISK}${NOCOLOR} with a capacity of ${BRIGHT_GREEN}${DISK_SIZE}${NOCOLOR}"
    case $PATTERN in
        zerofill|random)
            submsg "Scrubbing with ${BRIGHT_GREEN}${PASSES}${NOCOLOR} pass(es) of ${BRIGHT_YELLOW}${PATTERN}${NOCOLOR}"
            declare -i I=$PASSES
            pass="1"
            while [ $I -gt 0 ];do
                disk_fill "$DISK" "$PATTERN"
                I=$(($I-1))
                pass+=1
            done
            message "Overwrite ${BRIGHT_CYAN}DONE!${NOCOLOR}"
            ;;
        nnsa)
            submsg "Scrubbing with 4-pass ${BRIGHT_YELLOW}NNSA${NOCOLOR} method: 2x Random, 1x Zero, and check"
            exit_with_error 1 "${PATTERN} not implemented yet, see --help"
            ;;
        schneier)
            submsg "Scrubbing $DISK with modified version of Bruce ${BRIGHT_YELLOW}Schneier${NOCOLOR}'s 7 pass method: 5x Random Fill, 1x One(0xFF), 1x Zero"
            exit_with_error 1 "${PATTERN} not implemented yet, see --help"
            ;;
        none)
            # do no disk scrubbing, this is intended for use with -s to only
            # use the SATA secure erase command
            submsg "Skipping fill..."
            true
            ;;
        *)
            exit_with_error 1 "${PATTERN} is not a valid pattern! see --help"
            ;;
    esac

    # scrubs drive recovery data with SATA commands Checks if the Secure
    # Erase feature is turned on either in config, or by the -s option.
    if [ ${SECURE_ERASE} == "true" ];then
      # check_security_wipe() returns OK if erase is supported and available.
      # otherwise it just returns a reason we can pass to exit_with_error()
      se_check="$(check_security_wipe)"
      [[ $se_check != "OK" ]] && exit_with_error 1 "${se_check}"
      ssd_secure_erase "$DISK" || exit_with_error $? "ATA Secure Erase failed!"
    fi
    # check if we have an exit code $exit accumulates errors, and throws the
    # combined error message for debugging. It should loosely return an error
    # count as exit status
    exit 0
}
switch_checker "$@"
main $PARMS
