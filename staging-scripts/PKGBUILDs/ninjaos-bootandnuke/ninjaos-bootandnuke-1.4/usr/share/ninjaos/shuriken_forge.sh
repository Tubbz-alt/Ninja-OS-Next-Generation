#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This is it, the script that makes shurikens. A shuriken combines syslinux
# and mkinitcpio-nban (Ninja Boot'n'Nuke) to make a single use self-wiping
# automated book and nuke solution on a thumb drive. Use with care. The wipe
# pattern is identical to zeroize. See bootanuke.sh for more information.

TARGET=""
REUSE="FALSE"
INERT="FALSE"
NBANONLY="FALSE"
BOOTLOADER="extlinux"
MOUNT_POINT="/mnt/shuriken"
KERNEL_NAME="default"

#If the config exists, use config file
[ -f /etc/shuriken_forge.conf ] && source /etc/shuriken_forge.conf

#COLORING
BRIGHT=$(tput bold)
BRIGHTCYAN=$(tput bold;tput setaf 6)
BRIGHTRED=$(tput bold;tput setaf 1)
NOCOLOR=$(tput sgr0)

part_shuriken() {
    # This function creates a blank disk with EXT2 on it. parameter one is the
    # target.
    local -i exit=0
    local -i part_size=31 # size of partition in megabytes. makes the shuriken
                           # quicker than formating the entire drive.
    local target="$1"
    submsg "Formatting..."
    sudo umount -f ${target}* 2> /dev/null
    sudo dd if=/dev/zero of=${target} bs=128k count=1 &> /dev/null
    exit+=$?
    sync
    sudo parted -s ${target} mklabel msdos
    exit+=$?
    sudo parted -s ${target} -- mkpart primary 0 ${part_size} &> /dev/null
    exit+=$?
    sudo parted -s ${target} set 1 boot on
    exit+=$?
    sudo mkfs.ext2 -q -L SHURIKEN ${target}1
    exit+=$?
    sync
    return $exit
}

syslinux_install() {
    #install extlinux on the target. takes one parameter.
    local -i exit=0
    local target="$1"
    local mount_boot_dir="${MOUNT_POINT}/syslinux/"
    submsg "Installing bootloader..."
    sudo mkdir -p "${mount_boot_dir}"
    exit+=$?
    sudo cp -af /usr/lib/syslinux/bios/vesamenu.c32 "${mount_boot_dir}"

    sudo cp -af /usr/lib/syslinux/bios/chain.c32 "${mount_boot_dir}"
    sudo cp -af /usr/lib/syslinux/bios/libcom32.c32 "${mount_boot_dir}"
    sudo cp -af /usr/lib/syslinux/bios/libutil.c32 "${mount_boot_dir}"
    sudo cp -af /usr/lib/syslinux/bios/reboot.c32 "${mount_boot_dir}"

    #set correct kernel name.
    sed "s/vmlinuz-linux/vmlinuz-linux${KERNEL_NAME}/g" /usr/share/shuriken/extlinux.conf > /tmp/extlinux.conf
    exit+=$?

    sudo mv -f /tmp/extlinux.conf "${mount_boot_dir}"
    exit+=$?
    sudo cp -af /usr/share/shuriken/shuriken.jpg "${mount_boot_dir}"
    exit+=$?
    sudo dd if=/usr/lib/syslinux/bios/mbr.bin of=${target} bs=440 count=1 &> /dev/null
    exit+=$?
    sync
    sudo extlinux --install "${mount_boot_dir}" &> /dev/null
    exit+=$?
    sync
    return $exit
}
check_nban() {
  #check if nban is already compiled
  if [ -f /boot/nban.img ];then
      echo "TRUE"
    else
      echo "FALSE" 
  fi
}

check_sudo() {
    # test should equal "root", if it is, its working and we return a 0 exit 
    # value. otherwise we return 1 for error. This prints nothing, and we check
    # the value with either $? or using  [[ check_sudo ]] &&, interfacing with
    # shell boolean logic.
    local test=""
    test=$(sudo whoami 2> /dev/null )
    if [ ${test} == "root" ];then
        echo "TRUE"
      else
        echo "FALSE"
    fi
}

check_boot() {
    # Check to see if /boot is mounted read only.
    local -i exit
    sudo touch /boot/readwrite 2> /dev/null
    if [ $? -eq 0 ];then
        echo "READWRITE"
      else
        echo "READONLY"
    fi
    sudo rm -f /boot/readwrite 2> /dev/null
}

set_mount_point() {
    # make sure there is not a directory on our mount point, add a number and keep
    # incrementing until we find free name space
    local -i n=1
    local mount="${MOUNT_POINT}"
    while [ -d "${MOUNT_POINT}" ];do
        MOUNT_POINT="${mount}${n}"
        n+=1
    done
    sudo mkdir -p "${MOUNT_POINT}"
    return $?
}

help_and_exit() {
  echo "${BRIGHT}shuriken_forge.sh:${NOCOLOR}" 1>&2
  cat 1>&2 << EOF
This script makes a Ninja Shuriken. A Shuriken is the Ninja OS Boot and Nuke
script combined with a basic extlinux bootloader on a USB stick.

Booting a shuriken will wipe all the storage media attached to the computer
including the shuriken, leaving blank FAT32 formated media. Block device is the
/dev/sdX name of the USB stick you want to use.

	Usage:
	$ shuriken_forge [-options] <block device>

	Switches:

	-?, --help		This message

	-r, --reuse-nban	reuses a build nban initcpio image. This must
				be in /boot/ on the host Ninja OS system.

	-k, --kernel-name	Specify the kernel name, the default for Arch
				Linux the default is "default". use "default" or
				"linux" for the vanilla Arch Linux kernel.

	-n, --nban-only		Compile Ninja Boot'N'Nuke initcpio image only.
				do not make a shuriken.

        	-NOT IMPLEMENTED YET-
	-i, --inert		Makes an inert shuriken, for testing purposes
				only.

	-b, --bootloader	Specify the type of bootloader. Three options:
				extlinux, isolinux, and pxelinux.

EOF
exit 1
}

exit_with_error() {
    # parameter 1 is exit code, 2 is message, be sure to quote the message.
    message "${BRIGHTRED}ERROR:${NOCOLOR} ${2}" 1>&2
    sudo umount -f "${MOUNT_POINT}" &> /dev/null
    sudo rm -rf "${MOUNT_POINT}" &> /dev/null
    sudo rm -f /tmp/extlinux.conf &> /dev/null
    sudo mv -f /etc/mkinitcpio.d/nban.preset.orig /etc/mkinitcpio.d/nban.preset &> /dev/null
    sudo rm -f /tmp/nban.preset &> /dev/null
    exit $1
}

create_initcpio_nban() {
    ## Compile the Boot'N'Nuke image.
    #get /boot readwrite status
    local readonly="$(check_boot)"
    local -i exit=0
    #Test to make sure /boot is read
    submsg "Generating Ninja Boot'n'Nuke .img file..."
    sudo cp -af /etc/mkinitcpio.d/nban.preset /etc/mkinitcpio.d/nban.preset.orig
    sudo sed "s/vmlinuz-linux/vmlinuz-linux${KERNEL_NAME}/g" /etc/mkinitcpio.d/nban.preset > /tmp/nban.preset
    exit+=$?
    sudo mv -f /tmp/nban.preset /etc/mkinitcpio.d/
    exit+=$?
    [ ${readonly} == "READONLY" ] && sudo mount -o rw,remount /boot
    sudo mkinitcpio -p nban &> /dev/null
    exit+=$?
    [ ${readonly} == "READONLY" ] && sudo mount -o ro,remount /boot
    sudo mv -f /etc/mkinitcpio.d/nban.preset.orig /etc/mkinitcpio.d/nban.preset
    exit+=$?
    return $exit
}

copy_kernel_nban() {
    local -i exit=0
    submsg "Copying Kernel and Boot'n'Nuke image..."
    sudo cp -a /boot/nban.img "${MOUNT_POINT}"
    exit+=$?
    sudo cp -a /boot/vmlinuz-linux${KERNEL_NAME} "${MOUNT_POINT}"
    exit+=$?
    return $exit
}

clean_up() {
    local -i exit=0
    submsg "Cleaning up..."
    sudo umount -f "${MOUNT_POINT}"
    exit+=$?
    sudo rmdir "${MOUNT_POINT}"
    exit+=$?
    return $exit
}

nban_only() {
    #this only generates the nban mkinitcpio profile. It runs and exits.
    echo "  ${BRIGHTCYAN}--+$(tput setaf 7)Shuriken Forge${BRIGHTCYAN}+--${NOCOLOR}"
    create_initcpio_nban || \
        exit_with_error $? "Failed to make Boot'n'Nuke image, halting."
    message "Boot'n'Nuke image generation complete!"
    exit 0
}

message() {
    echo "${BRIGHT}shuriken_forge.sh:${NOCOLOR} $@"
}
submsg() {
    echo "		   $@"
}
switch_checker() {
    PARMS=""
    while [ ! -z "$1" ];do
        case "$1" in
          --help|-\?)
            help_and_exit
            ;;
          --reuse-nban|-r)
            REUSE="TRUE"
            ;;
          --inert|-i)
            INERT="TRUE"
            ;;
          --nban-only|-n)
            NBANONLY="TRUE"
            ;;
          --kernel-name|-k)
            [ -z $2 ] && exit_with_error 1 "when using -k you need to specify a kernel name, see --help"
            KERNEL_NAME=${2,,}
            shift
            ;;
          --bootloader|-b)
            [ -z $2 ] && exit_with_error 1 "when using -b you need to specify the name of the bootloader, see --help"
            BOOTLOADER=${2,,}
            shift
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
    TARGET="$1"
    KERNEL_NAME=${KERNEL_NAME,,}
    case $KERNEL_NAME in
      default|arch|linux)
        KERNEL_NAME=""
        ;;
      *)
        KERNEL_NAME="-${KERNEL_NAME}"
        ;;
    esac
    #Check if we can root with sudo, if not, exit
    [ $(check_sudo) != "TRUE" ] && exit_with_error 1 "Cannot get root with sudo"
    #If all we need to do make the Ninja Boot'n'Nuke, run this, it exits itself
    [ ${NBANONLY} == "TRUE" ] && nban_only

    # Input checking. If there is no target, display help. If the target is not
    # a block device, give an error
    [ -z ${TARGET} ] && help_and_exit
    [ ! -b ${TARGET} ] && exit_with_error 1 "${TARGET} is not a block device see --help"

    #Display the banner and get to to work.
    echo "  ${BRIGHTCYAN}--+$(tput setaf 7)Shuriken Forge${BRIGHTCYAN}+--${NOCOLOR}"
    message "Making Shuriken on ${TARGET}"

    # generate the nban initcpio image. Lets do this first. Lets check to make
    # sure we aren't supposed to re-use the nban from last time. This saves a
    # lot of time, as this is the most time consuming step.
    REUSE=${REUSE,,} #lower case
    case ${REUSE} in
      false)
        create_initcpio_nban || \
            exit_with_error $? "Failed to make Boot'n'Nuke image, halting."
        ;;
      true)
        [[ $(check_nban) == "FALSE" ]] && exit_with_error 1 "--reuse-nban selected, but no nban image can be found, see --help"
        true
        ;;
      *)
        exit_with_error 1 "bad REUSE= option, the script should never throw this error, debug"
        ;;
    esac

    #Partition the drive. one MBR partition, also, zerofill the beginning first
    part_shuriken "${TARGET}" || \
        exit_with_error $? "partitioning failed, halting."

    # Mount the partion, we are going to stay mounted until we are done.
    set_mount_point || \
        exit_with_error $? "Cannot create directory ${MOUNT_POINT}, halting."
    sudo mount -t ext2 ${TARGET}1 "${MOUNT_POINT}" || \
        exit_with_error $? "Cannot mount ${TARGET}1 on ${MOUNT_POINT}, halting."

    #Install the bootloader extlinux
    syslinux_install "${TARGET}" || \
        exit_with_error $? "Bootloader install failed, halting."

    #Copy the kernel and the nban.img we made earlier
    copy_kernel_nban || \
        exit_with_error $? "Failed to copy Boot'n'Nuke and/or kernel"
    sync

    #set immutable bit on everything
    #sudo chattr -R +i "$MOUNT_POINT" #throws errors for some reason, next ver

    #unmount the partition and remove the mount point
    clean_up || \
        exit_with_error $? "Cleanup failed, since we got this far the shuriken most likely works, but you'll need to clean up /mnt/ manually"

    message "Shuriken is ready on ${TARGET} ${BRIGHTCYAN}DONE!${NOCOLOR}"
    exit 0
}
switch_checker "${@}"
main ${PARMS}
