#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script will create a clone of the running copy Ninja OS into .img files
# suitable for use with makeninja.sh and ninjaforge.sh
# There are two options --package, which will repackage Ninja OS for
# for redistribution, and --dupe, which will copy from USB stick to USB stick.

# override automatic location detection in version file in case its local.
# (force to use system file.
source /usr/share/scripts/liveos_lib.sh
source /var/liveos_version.conf
OSSLUG=${OSNAME,,}
OSSLUG=${OSSLUG//[[:blank:]]/}
TARGET="$1"
MAINIMG="${OSSLUG}_${OSVERSION}.img"
BOOTSECTOR="ninjabootsector${OSVERSION}.img"
DUPE="FALSE"
PACKAGE="FALSE"
HASH="FALSE"

liveos_dupe() {
    local -i exit=0
    #check if target is a block device
    [ ! -b "${TARGET}" ] && exit_with_error 1 "cannot duplicate ${OSNAME} to ${TARGET}, not a block device"
    [ "${TARGET}" == "${BOOTDEV}" ] && exit_with_error 1 "cannot duplicate ${OSNAME} to ${TARGET}, ${TARGET} is the OS block device."
    #Partition the new drive for Ninja OS
    /usr/share/scripts/ninjaforge.sh --partonly "${TARGET}"
    exit+=$?

    message "Duplicating Running(${BRIGHT}${OSNAME} ${OSVERSION} ${OSARCH}${NOCOLOR}) system to ${BRIGHT_YELLOW}${TARGET}${NOCOLOR}. This may take a while..."
    #copy boot sector
    submsg "${BRIGHT_YELLOW}${BOOTDEV}${NOCOLOR} -> ${BRIGHT_YELLOW}${TARGET}${NOCOLOR}:"
    sudo dd if="${BOOTDEV}" bs=440 count=1 2> /dev/null | pv -s 440| sudo dd of="${TARGET}" bs=440 count=1 &> /dev/null
    exit+=$?
    sync
    #copy operating system
    submsg "${BRIGHT_YELLOW}${BOOTPART}${NOCOLOR} -> ${BRIGHT_YELLOW}${TARGET}1${NOCOLOR}:"
    sudo dd if="${BOOTPART}" bs=128k 2> /dev/null |pv -B 128k -s ${PART_SIZE}m | sudo dd of="${TARGET}1" bs=128k &> /dev/null
    exit+=$?
    sync
    return $exit
}

liveos_clone() {
    local -i exit=0
    [ ! -d "${TARGET}" ] && exit_with_error 1 "cannot clone ${OSNAME} to ${TARGET}, not a directory"
    message "Cloning Running(${BRIGHT}${OSNAME} ${OSVERSION} ${OSARCH}${NOCOLOR}) system into .img files. This may take a while..."
    #now lets grab the operating system with dd
    submsg "${BRIGHT_YELLOW}${BOOTPART}${NOCOLOR} -> ${BRIGHT_GREEN}${MAINIMG}${NOCOLOR}:"
    sudo dd if=${BOOTPART} bs=128k 2> /dev/null |pv -B 128k -s ${PART_SIZE}m | dd of="${TARGET}/${MAINIMG}" bs=128k &> /dev/null
    exit+=$?
    #now the boot sector
    submsg "${BRIGHT_YELLOW}${BOOTDEV}${NOCOLOR} -> ${BRIGHT_GREEN}${BOOTSECTOR}${NOCOLOR}:"
    sudo dd if=${BOOTDEV} bs=440 count=1 2> /dev/null | pv -s 440| dd of="${TARGET}/${BOOTSECTOR}" bs=440 count=1 &> /dev/null
    exit+=$?
    sync
    return $exit
}

# This needs to be run after liveos_clone and assumes the .img files exist
liveos_package() {
    local -i exit=0
    local package_dir="${TARGET}/${OSSLUG}-${OSARCH}-${OSVERSION}"
    local package_name="${OSSLUG}-${OSARCH}-${OSVERSION}.liveos.zip"
    if [[ ! -f "${TARGET}/${MAINIMG}"  ||  ! -f "${TARGET}/${BOOTSECTOR}" ]];then
        exit_with_error 1 "Can't find ${OSNAME} image and/or bootsector to package, aborting"
    fi
    message "Packing .img, and install files into ${package_name}"
    #lets make a temp directory and then fill it with files
    mkdir -p "${package_dir}"
    exit+=$?
    mkdir "${package_dir}/doc"
    mkdir "${package_dir}/scripts"
    mkdir "${package_dir}/hash"
    mkdir "${package_dir}/gpg"
    mv "${TARGET}/${MAINIMG}" "${package_dir}/"
    exit+=$?
    mv "${TARGET}/${BOOTSECTOR}" "${package_dir}/"
    exit+=$?
    cp /usr/share/scripts/install/*.sh "${package_dir}/scripts/"
    exit+=$?
    cp /usr/share/scripts/install/README "${package_dir}/doc/"
    exit+=$?
    cp /var/liveos_version.conf "${package_dir}/"
    exit+=$?
    cp /usr/share/licenses/common/GPL3/license.txt "${package_dir}/doc/"
    exit+=$?

    if [ "${HASH}" == "TRUE" ];then
      #compute hash sums and put them in md5/ this can be slow
      submsg "Generating MD5 sums, this might take a while..."
      local main_img_hash=$(md5sum "${package_dir}/${MAINIMG}" | cut -f 1 -d " ")
      exit+=$?
      local bs_img_hash=$(md5sum "${package_dir}/${BOOTSECTOR}" | cut -f 1 -d " ")
      exit+=$?
      local index_hash=$(md5sum "${package_dir}/liveos_version.conf" | cut -f 1 -d " ")
      exit+=$?
      #get a hash of scripts in scripts/ 
      local lib_sh_hash=$(md5sum "${package_dir}/scripts/liveos_lib.sh" | cut -f 1 -d " ")
      exit+=$?
      local forge_sh_hash=$(md5sum "${package_dir}/scripts/ninjaforge.sh" | cut -f 1 -d " ")
      exit+=$?
      [ $exit -ne 0 ] && exit_with_error 1 "Cannot generate MD5 hash sums!"
      cat > "${package_dir}/hash/md5" << EOF
#Hash Sums file
# This file contains the MD5 checksums for Ninja OS image files so you can
# verify the contents were not altered in shipping. This file is automaticly
# generated. See ../README for more information
#
# MAIN_MD5= contains the hash for the main image. BS_MD5= for the boot sector

EOF
exit+=$?
      echo "MAIN_HASH=${main_img_hash}" >> "${package_dir}/hash/md5"
      exit+=$?
      echo "BS_HASH=${bs_img_hash}" >> "${package_dir}/hash/md5"
      echo "INDEX_HASH=${index_hash}" >> "${package_dir}/hash/md5"
      echo "LIB_SH_HASH=${lib_sh_hash}" >> "${package_dir}/hash/md5"
      echo "FORGE_SH_HASH=${forge_sh_hash}" >> "${package_dir}/hash/md5"
      exit+=$?
      [ $exit -ne 0 ] && exit_with_error 1 "Could not write MD5 sums to package!"
      submsg "MD5 complete"
    fi
    #compress the directory into a zip file
    cd "${package_dir}"
    submsg "Compressing Package..."
    zip -qr "${package_name}" .
    exit+=$?
    mv "${package_name}" ..
    exit+=$?
    rm -rf "${package_dir}"
    exit+=$?
    sync
    [ $exit -ne 0 ] && exit_with_error 1 "Could not compress package!"
    return 0
}

clone_help() {
    echo "${BRIGHT}${SCRIPT_NAME}:${NOCOLOR}" 1>&2
cat 1>&2 << EOF

	Clones the currently running Ninja OS system into .img files suitable
for use with the forge command. If run with no options, it will clone to the
present dirrectory. If a directory is specified, the files will be made there.

	usage:
	$ cloneninja.sh <target-directory>

	Options:
	-a, --hash	Include a file with MD5 checksums of the .img files in
			in the package. only works with --package

	-d, --dupe	Copies dirrectly to another device(block) without making
			.img files

	-k, --package	Makes a complete re-distributable .zip file with forge
			scripts, README, and licensing files

EOF
exit 1
}

#$1 is the error code, $2 is the message, be sure to put $2 in "quotes"
exit_with_error() {
    message "${BRIGHT_RED}ERROR:${NOCOLOR} ${2}" 1>&2
    rm -f ${MAINIMG} &> /dev/null
    rm -f ${BOOTSECTOR} &> /dev/null
    exit $1
}
message() {
    echo "${BRIGHT}${SCRIPT_NAME}:${NOCOLOR} ${@}"
}
submsg() {
    echo "	       ${@}"
}

#New Options checker
switch_checker() {
  PARMS=""
  while [ ! -z "$1" ];do
    case "$1" in
      --help|-\?)
        clone_help
        ;;
      --package|-k)
        PACKAGE="TRUE"
        ;;
      --hash|-a)
        HASH="TRUE"
        ;;
      --dupe|-d)
        DUPE="TRUE"
        ;;
      *)
        ##This is not a switch, we make the new command line without
        # without switches. counting can be done with ${#}
        PARMS="${PARMS} $1"
        ;;
    esac
    shift
  done
}

# main program options checker is called at the end, and main run with a
# filtered command line.
main() {
    trap "exit_with_error 1 'Aborted!' " SIGINT SIGTERM #exit cleanly with an abort
    TARGET="$1"
    [ -z "${TARGET}" ] && TARGET="${PWD}"

    # main part, where we decide on action to take, either dupe to another USB
    # stick, or clone to files.
    if [ "${DUPE}" == "TRUE" ];then
        liveos_dupe "${TARGET}" || exit_with_error 1 "${OSNAME} duplication to ${TARGET} failed!"
      else
        liveos_clone "${TARGET}" || exit_with_error 1 "${OSNAME} clone failed!"
        if [ ${PACKAGE} == "TRUE" ];then
          liveos_package || exit_with_error 1 "Packaging of ${OSNAME} failed!"
        fi
    fi

    # print done and exit. All error checking is localized now. 
    echo "${BRIGHT_CYAN}DONE!${NOCOLOR}"
    exit 0
}
#New options checker
switch_checker "${@}"
main $PARMS
