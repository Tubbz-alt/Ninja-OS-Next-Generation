#!/bin/bash

#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# The script is to automaticly make a new Ninja OS USB Stick on specified block
# device (e.g. /dev/sdb) This should work on any read/write medium however.
# This will erase the entire drive in the proccess.(leaving a clean NinjaOS
# install). The USB Stick needs enough room for the partition. see
# liveos_version.conf for the partition size.

source /usr/share/scripts/liveos_lib.sh
# defaults
TARGET=""
PRINT_META="FALSE"
PACKAGE="FALSE"
PART_ONLY="FALSE"
CHECK_HASH="FALSE"
CHECK_GPG="FALSE"
CHECK_ONLY="FALSE"
NO_PART="FALSE"
declare -i P=1 # ${P} is disk parition number, i.e. /dev/sdX1

OK_COLOR="${BRIGHT_CYAN}OK!${NOCOLOR}"
FAIL_COLOR="${BRIGHT_RED}¡FAILS!${NOCOLOR}"

set_filenames(){
    # set main image and boot sector filenames. this may be re-done if we are
    # reading from a package
    OSSLUG=${OSNAME,,}
    OSSLUG=${OSSLUG//[[:blank:]]/}
    MAINIMG="${OSSLUG}_${OSVERSION}.img"
    BOOTSECTOR="ninjabootsector${OSVERSION}.img"
}

part_ninja() {
    local target="$1"
    local -i exit=0
    local -i disksize=0

    #old size versions < 0.8.x 
    #local mindisksize="976562"
    #new size 2 GB
    local -i mindisksize=1948672  #this is 1995 MB, yes this is magic number.
    local -i warndisksize=3915770 #This is is a 4GB microcenter USB stick

    # Lets Check to make sure the disk is big enough first
    disksize=$(sudo sfdisk -s ${target})
    if [ ${disksize} -lt ${mindisksize} ];then
        exit_with_error 1 "${target} is less than ${BRIGHT_RED}${PART_SIZE}MB${NOCOLOR}, and cannot be set up for use with ${OSNAME}. Quitting..."
      elif [ ${disksize} -lt ${warndisksize} ];then
        warn "${target} has more than ${BRIGHT_YELLOW}${PART_SIZE}MB${NOCOLOR} but less than ${BRIGHT_GREEN}$(($PART_SIZE *2))MB${NOCOLOR} of disk space. Script will continue, but results will be sub-optimal."
    fi
    message "Setting up partitions in ${BRIGHT_YELLOW}${target}${NOCOLOR} for ${BRIGHT}${OSNAME} ${OSVERSION}${NOCOLOR}..."

    # Start with making sure all file systems on device are unmounted.
    sudo umount ${target}? &> /dev/null

    # Wipe and remake the parition now
    sudo dd if=/dev/zero of=${target} bs=128k count=1 &> /dev/null
    exit+=$?
    sync
    sudo parted -s ${target} mklabel msdos
    exit+=$?

    # Make the operating system partition
    sudo parted -s ${target} mkpart primary 0 ${PART_SIZE} &> /dev/null
    exit+=$?
    sudo parted -s ${target} set 1 boot on
    exit+=$?

    # Now make a second partition that fills the rest of the disk
    sudo parted -s ${target} -- mkpart primary ${PART_SIZE} -1 &> /dev/null
    exit+=$?
    sync

    # print error message and return
    [ ${exit} -eq 0 ] && donemsg
    [ ${exit} -ne 0 ] && failmsg
    return $exit
}

print_info_item() {
    echo "${1}:	${BRIGHT}${2}${NOCOLOR}"
}
#_d is for double spaced
print_info_item_d(){
    echo "${1}:		${BRIGHT}${2}${NOCOLOR}"
}
print_info() {
    submsg "-Metadata-"
    [ ${PACKAGE} == "TRUE" ] && print_info_item "Package File" "${PACKAGE_FILE}"
    print_info_item "Package Revision" "${FORMAT_VER}"
    print_info_item_d "Name" "${OSNAME} ${OSVERSION}"
    print_info_item "Machine" "${OSARCH}"
    print_info_item "Parition Size" "${PART_SIZE} MegaBytes"
    print_info_item "GPG Key" "${CONF_KEYSIG}"

    ## Integrity Check
    # Lets only unzip the main image once, its huge and takes a long time.
    if [ ${CHECK_ONLY} == "TRUE" ];then
      if [[ ${CHECK_HASH} == "TRUE" || ${CHECK_GPG} == "TRUE" ]];then
        message "Integrity Check on ${PACKAGE_FILE}, this might take a while..."
        unzip_package "${PACKAGE_FILE}" || \
          exit_with_error $? "Cannot unzip ${PACKAGE_FILE}"
      fi
    fi

    # hash sum --hash, -a
    if [ ${CHECK_HASH} == "TRUE" ];then
        message "Checking MD5 Hashsums..."
        check_package_hash "${PACKAGE_FILE}"
    fi

    # gpg signature checking, -g, --gpg
    if [ ${CHECK_GPG} == "TRUE" ];then
        message "Checking GPG signatures..."
        check_package_gpg "${PACKAGE_FILE}"
    fi

    echo ""
}

source_package_index() {
    # this routine loads the version index from a .zip package
    local -i exit=0
    local filename="$1"
    unzip -qq "${filename}" liveos_version.conf -d /tmp &> /dev/null
    exit+=$?
    source /tmp/liveos_version.conf
    exit+=$?
    # package revisions need to be whole numbers. We shipped 0.11.1 with
    # format ver 1.1 Fix it, before it crashes the script.
    [ $FORMAT_VER == "1.1" ] && declare -i FORMAT_VER=1
    rm -f /tmp/liveos_version.conf
    # Correct these two variables using data gotten from the package.
    set_filenames
    return ${exit}
}

unzip_package() {
    # unzips operating system from package before copying
    local -i exit=0
    local filename="$1"
    unzip -qq "${filename}" "${MAINIMG}" &> /dev/null
    exit+=$?
    unzip -qq "${filename}" "${BOOTSECTOR}" &> /dev/null
    exit+=$?
    unzip -qq "${filename}" "liveos_version.conf" &> /dev/null
    exit+=$?
    unzip -qq "${filename}" "scripts/liveos_lib.sh" &> /dev/null
    exit+=$?
    unzip -qq "${filename}" "scripts/ninjaforge.sh" &> /dev/null
    exit+=$?
    return ${exit}
}

check_hash() {
    # this function checks two hash sum value and outputs the result.
    # check_hash <sum1> <sum2> <name> <spacing>
    # quote everything please. 
    local sum1="$1"
    local sum2="$2"
    local name="$3"
    local spacing="$4"
    if [ "${sum1}" == "${sum2}" ];then
        submsg "${name} Hash${spacing}${OK_COLOR}"
        return 0
      else
        submsg "${name} Hash${spacing}${FAIL_COLOR}"
        return 1
    fi
}
check_package_hash() {
    # this function checks the MD5 hashsums of a LiveOS package. returns
    # the amount of errors
    local filename="$1"
    local -i exit=0

    # unzip the file with the stored hashes, and then load the values into the
    # script with source.
    unzip -qq "${filename}" "hash/md5" -d /tmp/ &> /dev/null
    source /tmp/hash/md5 || \
      exit_with_error 1 "Failed to read package MD5 Sums, make sure ${filename} is a(n) ${OSNAME} package, and we can read it"
    rm -rf /tmp/hash/

    # Check the index( This appears in file revision 2)
    if [ $FORMAT_VER -ge 2 ];then
      local index_hash=$(md5sum "liveos_version.conf" | cut -f 1 -d " " ) || \
        exit_with_error 1 "Cannot computer index file hash"
      check_hash "${index_hash}" "${INDEX_HASH}" "Index File" "		"
      exit+=$?
    fi

    # Check the boot sector
    local bs_img_hash=$(md5sum "${BOOTSECTOR}" | cut -f 1 -d " ") || \
      exit_with_error 1 "Cannot compute boot sector hash!"
    check_hash "${bs_img_hash}" "${BS_HASH}" "Bootsector" "		"
    exit+=$?

    # Check the main image
    local main_img_hash=$(md5sum "${MAINIMG}" | cut -f 1 -d " ") || \
      exit_with_error 1 "Cannot compute main image hash"
    check_hash "${main_img_hash}" "${MAIN_HASH}" "Main Image" "		"
    exit+=$?

    # Check the scripts (This starts in file version 2)
    if [ $FORMAT_VER -ge 2 ];then
      local lib_sh_hash=$(md5sum scripts/liveos_lib.sh | cut -f 1 -d " " ) || \
        exit_with_error 1 "Cannot compute bash lib hash"
      check_hash "${lib_sh_hash}" "${LIB_SH_HASH}" "Bash Lib" "		"
      exit+=$?
      local forge_sh_hash=$(md5sum scripts/ninjaforge.sh | cut -f 1 -d " " ) || \
        exit_with_error 1 "Cannot compute Ninja Forge hash"
      check_hash "${forge_sh_hash}" "${FORGE_SH_HASH}" "Ninja Forge" "		"
      exit+=$?
    fi

    # print error status and return
    if [ ${exit} -ne 0 ];then
        submsg "${BRIGHT_RED}${exit}${NOCOLOR} Failure(s), ${filename} is ${BRIGHT_RED}!Damaged!${NOCOLOR}"
      else
        submsg "${BRIGHT_CYAN}0${NOCOLOR} Failures, Hashsum	${BRIGHT_CYAN}PASS!${NOCOLOR}"
    fi
    return $exit
}

gpg_check(){
    # use as gpg_check <sig_file> <file_to_check> <name> <spacing>
    local sig="${1}"
    local check="${2}"
    local name="${3}"
    local spacing="${4}"
    gpg --no-default-keyring --keyring "${GPG_KEYRING}" --verify "${sig}" "${check}" 2> /tmp/temp_int
    if [ $? -eq 0 ];then
        submsg "${name} Signature${spacing}${OK_COLOR}"
        return 0
      else
        submsg "${name} Signature${spacing}${FAIL_COLOR}"
        return 1
    fi
}
check_package_gpg(){
    # this function checks the GPG signatures of a LiveOS package. returns the
    # amount of errors
    local filename="$1"
    local -i exit=0

    # First we check the GPG key
    KEY_CHECK=$(gpg_check_key)
    if [ ${KEY_CHECK} != "TRUE" ];then
        warn "Key in use does not match key in index, the OS is using ${GPG_KEYNAME}"
    fi

    # Next we extract the signature files
    unzip -qq "${filename}" "gpg/${BOOTSECTOR}.sig" -d /tmp/ &> /dev/null
    exit+=$?
    unzip -qq "${filename}" "gpg/${MAINIMG}.sig" -d /tmp/ &> /dev/null
    exit+=$?
    if [ $FORMAT_VER -ge 2 ];then
        unzip -qq "${filename}" "gpg/liveos_version.conf.sig" -d /tmp/ &> /dev/null
        exit+=$?
        unzip -qq "${filename}" "gpg/liveos_lib.sh.sig" -d /tmp/ &> /dev/null
        exit+=$?
        unzip -qq "${filename}" "gpg/ninjaforge.sh.sig" -d /tmp/ &> /dev/null
        exit+=$?
    fi
    [ ${exit} -ne 0 ] && exit_with_error 1 "Cannot read GPG signatures from ${filename}"

    # Check if key used matches keyname in the version file
    [ "${GPG_FINGERPRINT}" != "${CONF_KEYSIG}" ] && warn "GPG keyring does not match key in version file"

    # Check signatures
    if [ $FORMAT_VER -ge 2 ];then
        gpg_check "/tmp/gpg/liveos_version.conf.sig" "liveos_version.conf" "Index File" "	"
        exit+=$?
    fi
    gpg_check "/tmp/gpg/${BOOTSECTOR}.sig" "${BOOTSECTOR}" "Bootsector" "	"
    exit+=$?
    gpg_check "/tmp/gpg/${MAINIMG}.sig" "${MAINIMG}" "Main Image" "	"
    exit+=$?
    if [ $FORMAT_VER -ge 2 ];then
        gpg_check "/tmp/gpg/liveos_lib.sh.sig" "scripts/liveos_lib.sh" "Bash Lib" "	"
        exit+=$?
        gpg_check "/tmp/gpg/ninjaforge.sh.sig" "scripts/ninjaforge.sh" "Ninja Forge" "	"
        exit+=$?
    fi

    # display GPG status
    if [ ${exit} -ne 0 ];then
        submsg "${BRIGHT_RED}${exit}${NOCOLOR} Failure(s), ${filename} is ${BRIGHT_RED}!Compromised!${NOCOLOR}"
      else
        submsg "${BRIGHT_CYAN}0${NOCOLOR} Failures, GPG Check	${BRIGHT_CYAN}PASS!${NOCOLOR}"
    fi

    #cleanup and exit
    rm -rf "/tmp/gpg" &> /dev/null
    return $exit
}

final_cleanup() {
    # cleanup the mess we made, all files we made or extracted get deleted.
    if [ ${PACKAGE} == "TRUE" ];then
        rm -f "${MAINIMG}" &> /dev/null
        rm -f "${BOOTSECTOR}" &> /dev/null
        rm -rf scripts/ &> /dev/null
        rm -f liveos_version.conf &> /dev/null
    fi
    rm -f /tmp/liveos_version.conf &> /dev/null
    rm -rf /tmp/hash &> /dev/null
    rm -rf /tmp/gpg/ &> /dev/null
}

make_ninja() {
    ## This function does the actual copying of Ninja OS to the USB stick
    # Basic input checking
    local target="$1"
    #Sanity check on inputs.
    [ ! -f "${MAINIMG}" ] && exit_with_error 1 "${MAINIMG} not found in local directory, exiting..."
    [ ! -f "${BOOTSECTOR}" ] && exit_with_error 1 "${BOOTSECTOR} not found in local directory, exiting..."
    [ ! -b ${target}${P} ] && exit_with_error 1 "${target} does not have partitioning setup, exiting..."
    
    # lets ask a sudo password now, rather than later. if we need a password,
    # sudo should cache it so the script runs uninterrupted later.
    [ $(check_sudo) != "TRUE" ] && exit_with_error 1 "Cannot get root with sudo, aborting..."

    ##Here is where we start to do the copy. NOTE: ${P} is the parition number
    # start with the main image. if we can find "pv" on the system we use it for
    # a status bar.
    message "Copying (${BRIGHT}${OSNAME} ${OSVERSION} $OSARCH${NOCOLOR}) system data to ${BRIGHT_YELLOW}${target}${NOCOLOR}. Be patient this might take a while..."

    # Main partition
    submsg "${BRIGHT_GREEN}${MAINIMG}${NOCOLOR} -> ${BRIGHT_YELLOW}${target}${P}${NOCOLOR}:"
    if [ -f $(which pv) ];then
        dd if="${MAINIMG}" bs=128k 2> /dev/null | pv -B 128k -s ${PART_SIZE}m | sudo dd of=${target}${P} bs=128k &> /dev/null || \
          exit_with_error $? "Operating System image copy failed!"
      else
        sudo dd if="${MAINIMG}" of=${target}${P} bs=128k status=progress || \
          exit_with_error $? "Operating System image copy failed!"
    fi

    # Bootsector
    submsg "${BRIGHT_GREEN}${BOOTSECTOR}${NOCOLOR} -> ${BRIGHT_YELLOW}${target}${NOCOLOR}:"
    if [ -f $(which pv) ];then
        sudo dd if="${BOOTSECTOR}" bs=440 count=1 2> /dev/null | pv -s 440 | sudo dd of="${target}" bs=440 count=1 &> /dev/null || \
          exit_with_error $? "Bootsector installation failed!"
      else
        sudo dd if="${BOOTSECTOR}" of="${target}" bs=440 count=1 status=progress || \
          exit_with_error $? "Bootsector installation failed!"
    fi

    #Sync to make sure the disk physically writes
    sync
    echo "${BRIGHT_CYAN}DONE!${NOCOLOR}"
}

exit_with_error() {
    # parameter 1 is exit code, 2 is message, be sure to quote the message.
    message "${BRIGHT_RED}ERROR:${NOCOLOR} $2" 1>&2
    final_cleanup
    exit $1
}
warn() {
    message "${BRIGHT_YELLOW}WARNING!${NOCOLOR} $@" 1>&2
}
message() {
    echo "${BRIGHT}${SCRIPT_NAME}:${NOCOLOR} $@"
}
submsg() {
    echo "	      $@"
}
donemsg() {
    echo "${BRIGHT_CYAN}DONE!${NOCOLOR}"
}
failmsg() {
    echo "${BRIGHT_RED}!FAIL!${NOCOLOR}"
}

help_and_exit() {
    echo "${BRIGHT}${SCRIPT_NAME}:${NOCOLOR}" 1>&2
cat 1>&2 << EOF
	Ninja Forge is a tool that creates new Ninja OS USB sticks. It functions
by formating a drive and then reconstituting Ninja OS from .img files generated
previously by Ninja Clone. You can use any USB stick that is larger than the
partition size(see liveos_version.conf). Ninja Forge will throw a warning for
USB sticks less than double the size of the image.

	When partitioning, it makes two partitions. One OS partition, and the
other blank, presumably for data. The OS partition is whatever size is set in
liveos_version.conf and the blank partition is the size of the remainder of the
USB drive. Upgrades however can write to any partition you so choose(see -p
below).

	It is possible to upgrade a previous install using --upgrade that
preserves data or other contents on the flash drive. Please note that --upgrade
defaults to partition one, and does not checking to ensure this is correct. If
Ninja OS is not installed to Parition 1, you will need to set partition manually
with -p

We take one parameter on the command line, and thats the block device name
(/dev/sdX)

	Usage:
	$ ninja_forge [--options] <block device>

	Options:
	-?, --help	This message

	-k, --package	Use a .liveos.zip package instead of files in a
			directory.
			WARNING: This needs space in the local directory to
			unzip the package file. Use as -k <filename>

	-m, --meta	Print versioning information in addition to other
			operations

			  Additional Meta Options:
	  -a, --hash	Checks hash sums in addition to other operations.
	  -g, --gpg	Check GPG signatures in addition to other operations.
	  -o, --noop	Don't partition or copy data, for use with -m, -a and -g


	-n, --part-num	Disk Partition Number. Default is 1. i.e. as /dev/sda1

	-p, --partonly	Format the disk and partition only. Do not copy any
			data.

	-u, --upgrade	Upgrade from a previous version of Ninja OS. i.e. skip
			formating.

	-v,--verify	Verify a package, alias for --meta --hash --noop --gpg
			--package --verify <filename>

EOF
exit 2
}
switch_checker() {
    PARMS=""
    while [ ! -z "$1" ];do
        case "$1" in
          --help|-\?)
            help_and_exit
            ;;
          --meta|-m)
            PRINT_META="TRUE"
            ;;
          --hash|-a)
            CHECK_HASH="TRUE"
            ;;
          --gpg|-g)
            CHECK_GPG="TRUE"
            ;;
          --package|-k)
            PACKAGE="TRUE"
            [ -z $2 ] && exit_with_error 1 "No package specified with --package"
            PACKAGE_FILE="$2"
            shift
            ;;
          --part-num|-n)
            [ "$2" -eq "$2" 2> /dev/null ] && P=$2
            [ -z $P ] && exit_with_error 1 "when using --part-num you need to specify a number, see --help"
            shift
            ;;
          --noop|-o)
            CHECK_ONLY="TRUE"
            ;;
          --partonly|-p)
            PART_ONLY="TRUE"
            ;;
          --upgrade|-u)
            NO_PART="TRUE"
            ;;
          --verify|-v)
            CHECK_ONLY="TRUE"
            PRINT_META="TRUE"
            CHECK_HASH="TRUE"
            CHECK_GPG="TRUE"
            PACKAGE="TRUE"
            [ -z $2 ] && exit_with_error 1 "No package specified with --verify"
            PACKAGE_FILE="$2"
            shift
            ;;
          *)
            PARMS+="$1"
            ;;
        esac
        shift
    done
    # check sanity check for conflicting options:
    [[ ${PART_ONLY} == "TRUE" && ${PACKAGE} == "TRUE" ]] && exit_with_error 1 "--partonly and --package cannot be used together"
    [[ ${PART_ONLY} == "TRUE" && ${CHECK_ONLY} == "TRUE" ]] && exit_with_error 1 "--partonly and --noop cannot be used together"
    [[ ${PART_ONLY} == "TRUE" && ${NO_PART} == "TRUE" ]] && exit_with_error 1 "--partonly and --upgrade cannot be used together"
}

main() {
    trap "exit_with_error 1 'Aborted!' " SIGINT SIGTERM #exit cleanly with an abort
    # Basic sanity checking.
    TARGET="$1"
    [[ -z $TARGET && ${CHECK_ONLY} != "TRUE" ]] && help_and_exit
    [[ ${CHECK_ONLY} != "TRUE" && ! -b ${TARGET} ]] && exit_with_error 1 "${TARGET} is not a block device, quitting..."

    #set values of $MAINIMG and $BOOTSECTOR
    set_filenames

    # if we are using packages, use the index file from the package. we do the
    # rest later. This has its own error handling.
    if [ ${PACKAGE} == "TRUE" ];then
        source_package_index "${PACKAGE_FILE}" || \
          exit_with_error $? "could not read ${PACKAGE_FILE} metadata, are you sure its a(n) ${OSNAME} package?"
        if [ ${CHECK_ONLY} != "TRUE" ];then  
          unzip_package  "${PACKAGE_FILE}" || \
            exit_with_error $? "could not unzip ${PACKAGE_FILE}, check to make sure the file system is read/write and there is enough disk space"
        fi
    fi

    # banner
    echo "${BRIGHT_CYAN} --+$(tput setaf 7)${OSNAME} System Forge${BRIGHT_CYAN}+-- ${NOCOLOR}"

    # Check and print the metadata
    [ ${PRINT_META} == "TRUE" ] && print_info
    if [ ${CHECK_ONLY} == "TRUE" ];then
        final_cleanup
        exit
    fi

    # Make sure we can root with sudo first
    [ $(check_sudo) != "TRUE" ] && exit_with_error 1 "Cannot get root with sudo"

    # Partition the USB Stick. Check for --upgrade and --partonly switches.
    if [ ${NO_PART} != "TRUE" ];then
        part_ninja ${TARGET} || \
          exit_with_error $? "Partitioning failed"
        [ ${PART_ONLY} == "TRUE" ] && exit
      else
        message "Upgrading ${BRIGHT_YELLOW}${TARGET}${NOCOLOR}"
    fi
    # Copy OS data to target
    make_ninja ${TARGET} || \
      exit_with_error $? "makeninja.sh returned an error($?) to us, .img files most likely did not transfer correctly"

    #cleanup and exit
    final_cleanup
    message "Finnished making ${BRIGHT}${OSNAME} ${OSVERSION} ${OSARCH}${NOCOLOR} on ${BRIGHT_YELLOW}${TARGET}${NOCOLOR}."
    exit
}

switch_checker "${@}"
main ${PARMS}

