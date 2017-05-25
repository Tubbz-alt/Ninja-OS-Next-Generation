#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#  Immmediately reboot into Ninja Boot'n'nuke. This requires that the nban image
#  be compiled with mkinitcpio previously. use mkinitcpio -p nban or
#  shuriken_forge -n. It also requires you be using syslinux.
#
#  This script is useful for if you lack time to manually reboot and select NBAN
#  and/or using a shuriken or pre-existing menu item is not an option.
#
#  CAUTION: THIS SCRIPT RUNS NINJA BOOT AND NUKE AND WILL ERASE ALL DATA ON YOUR
#  HARD DRIVE AND ALL OTHER ATTACHED DRIVES. USE WITH CARE.
CONFIRM="n"
KERNEL="aufs_friendly"
SYSLINUX_CFG="/boot/syslinux/syslinux.cfg"

syslinux_conf() {
  # overwrite syslinux conf to run nban at next boot
  mv ${SYSLINUX_CFG} ${SYSLINUX_CFG}.bak
  cat > ${SYSLINUX_CFG} << EOF
TIMEOUT 01
DEFAULT nuke
MENU TITLE `Boot Menu`

LABEL nuke
    MENU LABEL Ninja Boot'n'Nuke
    LINUX ../vmlinuz-linux${KERNEL}
    INITRD ../nban.img

EOF
}

nuke(){ 
  # At this point, we disabled interruptions.
  trap "true" SIGINT SIGTERM
  echo "Goodbye..."
  syslinux_conf
  # redundant to make sure they catch. They are also done in the background so
  # they cannot be interrupted.
  reboot -f &
  systemctl reboot -f &
  # This makes sure we do not return to a command prompt.
  while true;do
    sleep 2
  done
}

check_kernel(){
  KERNEL=${KERNEL,,}
  case $KERNEL in
    default|arch|linux)
      KERNEL=""
      ;;
    *)
      KERNEL="-${KERNEL}"
      ;;
  esac
}

check_req(){
  # This function checks if system requirements are met.
  # check if root
  [ $UID -ne 0 ] && abort "Script needs root!"
  # Check for syslinux config. If this file does not exist, it is not in use by
  # the system
  [ ! -f ${SYSLINUX_CFG} ] && abort "Cannot find SYSLINUX configuration at ${SYSLINUX_CFG}. This script will only work with syslinux bootloaders. Edit settings in the script and try again"
  # check if we can write to the syslinux config.
  touch ${SYSLINUX_CFG} || abort "Cannot write to syslinux configuration file at ${SYSLINUX_CFG}."
  # check if nban is compiled. use either mkinitcpio or shuriken forge to make
  [ ! -f /boot/nban.img ] && abort "NBAN is not built. Build with shuriken_forge -n or mkinitcpio -p nban"
  # Check if extlinux binary is installed, if not, reboot will most likely not
  # work.
  [ ! -f $(which extlinux) ] && abort "Cannot find EXTLINUX binary. This script will only work with syslinux bootloaders."
}

abort() {
  echo 1>&2 "reboot_nuke.sh: aborting nuke. ${@}"
  tpur sgr0
  exit 1
}

set_background() {
    tput setab 1
    tput setaf 8
    tput bold
}
warning() {
  #give a warning before we nuke.
  cat << EOF
	${GREY}+${BRIGHT_YELLOW}---${BRIGHT_WHITE}NINJA ${BRIGHT_YELLOW}BOOT ${BRIGHT_WHITE}AND ${GREY}NUKE${BRIGHT_YELLOW}---${GREY}+${WHITE}

This script will reboot into Ninja Boot'n'Nuke, wiping all data on all attached
storage media without a prompt. This is the only warning. If you press 'y' all
data will be erased, and will not be recoverable.

EOF
}

main() {
  trap "abort" SIGINT SIGTERM
  # requirements check
  check_req
  # set kernel name
  check_kernel
  [ "$1" == "noconfirm" ] && nuke
  # display a warning banner
  set_background
  warning
  # get confirmation from the user
  read -N 1 -p "ARE YOU SURE? (y/n)" CONFIRM
  CONFIRM=${CONFIRM,,}
  # If we get a confirmation, nuke
  [ ${CONFIRM} == "y" ] && nuke
  abort "User Canceled!"
}

main ${@}
