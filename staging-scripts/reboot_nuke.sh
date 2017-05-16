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
KERNEL="default"

syslinux_conf() {
  # overwrite syslinux conf to run nban at next boot
  cd /boot/syslinux/
  mv syslinux.conf syslinux.conf.bak
  cat > /boot/syslinux/syslinux.conf << EOF
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

abort() {
  echo 1>&2 "reboot_nuke.sh: aborting nuke. ${@}"
  exit 1
}

warning() {
  #give a warning before we nuke.
  cat << EOF
This script will reboot into Ninja Boot'n'Nuke, wiping all data on all attached
storage media without a prompt. This is the only warning. If you press 'y' all
data will be erased, and will not be recoverable.

EOF
}

main() {
  trap "abort" SIGINT SIGTERM
  # check if root
  [ $UID -ne 0 ] && abort "Script needs root!"
  [ ! -f /boot/syslinux/syslinux.cfg ] && abort "SYSLINUX is not installed. This script will only work with syslinux bootloaders."
  # check if nban is compiled. use either mkinitcpio or shuriken forge to make
  [ ! -f /boot/nban.img ] && abort "NBAN is not built. Build with shuriken_forge -n or mkinitcpio -p nban"
  # display a warning banner
  warning
  # get confirmation from the user
  read -N 1 -p "are you sure? (y/n)" CONFIRM
  CONFIRM=${CONFIRM,,}
  # If we get a confirmation, nuke
  [ ${CONFIRM} == "y" ] && nuke
  abort "User Canceled!"
}

main ${@}
