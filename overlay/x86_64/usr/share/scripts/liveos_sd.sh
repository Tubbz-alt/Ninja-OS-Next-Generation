#!/bin/bash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# Self Destruct/Zeroize. Do the UnThinkable. Wipe all data on USB stick, make a
# single blank FAT partition, then reboot.
#
# First it wipes the first 128k(all potential encrypted partition headers) from
# every partition of the drive with $RAND_SRC, making recovery of encrypted
# partions along with all filesystem tables, nigh impossible.
#
# Second, it zero fills the entire drive with $FILL_SRC.
#
# Third, and final, it re-partitions and reformats the disk as a FAT32 partition
# and reboots. This should make the USB drive look like a regular, blank
# universally compatible USB stick, with no trace that we were ever there.

source /usr/share/scripts/liveos_lib.sh
FILL_SRC=/dev/zero
RAND_SRC=/dev/urandom
NOCONFIRM="no"
BOOTMODE="no"
SURE="no"
GUI="yes"

GREY=$(tput bold;tput setaf 0)
BRIGHT_WHITE=$(tput bold;tput setaf 7)

#wipe the first 128k off every partition of the boot device
wipe_part_headers() {
  local parts="$(ls ${BOOTDEV}?)"
  for part in ${parts};do
    /tmp/emergency_bin/busybox dd if=${RAND_SRC} bs=128k count=1 of=${part} 2> /dev/null 
  done
  /tmp/emergency_bin/busybox dd if=${RAND_SRC} of=${BOOTDEV} bs=128k count=1 2> /dev/null
  /tmp/emergency_bin/busybox sync
}

set_wipe_env(){
  # set the enviroment variables to only use busybox based ram. not used for now
  cd /tmp/emergency_bin/
  ln -s busybox dd; ln -s busybox sync
  ln -s busybox mkfs.vfat; ln -s busybox sleep
  ln -s busybox reboot; ln -s busybox poweroff
  PATH=/tmp/emergency_bin
}

scrub_disk() {
  # This is the dirty work, lets start by trapping the escape commands,
  # changing to virtual terminal 1, stopping the only other running virtual
  # terminal(tty2), and disabling logins by locking root and making a blank
  # file at /etc/nologin. We disable console logging and interrupt keys.
  # This secures the console, making the machine impossible to access, and self
  # destruct sequence impossible to abort, or otherwise gather any visual
  # information about the running system. Also disables any and all network
  # connections.
  #
  # powerbutton presses are now ignored, and ctrl-alt-delete does nothing. A
  # keyboard interrupt will skip to the last stage of reformatting the disk
  # and then rebooting. Future versions might tie reboot and shutdown to this
  # as well
  local pids=""
  trap "finale" 1 2 9 15 17 19 23
  sudo chvt 1 &
  pids+=" $!"
  sudo systemctl mask reboot.target & # prevent console reboots
  pids+=" $!"
  sudo systemctl mask shutdown.target & # prevent console shutdowns
  pids+=" $!"
  sudo systemctl mask systemd-journald & #Stop logging
  pids+=" $!"                            # |
  sudo systemctl stop systemd-journald & # +
  pids+=" $!"
  sudo sysctl -w kernel.printk="0 7 0 0" &
  pids+=" $!"
  sudo dmesg --console-off &
  pids+=" $!"
  sudo systemctl stop NetworkManager &
  pids+=" $!"
  sudo systemctl stop bluetooth &
  pids+=" $!"
  sudo systemctl stop getty@tty2.service &
  pids+=" $!"
  sudo systemctl stop postgresql &
  pids+=" $!"
  sudo usermod -L root &
  pids+=" $!"
  sudo touch /etc/nologin &
  pids+=" $!"
  # tasks are now parallel, we use to the wait to make sure they are done
  # before continuing
  wait ${pids}
  # Clear the screen and remove all formating. This is so no one can see what
  # the computer was doing before SD/Z
  clear
  tput sgr0
  # Before we start, scrub RAM (not implemented, this doesn't work reliabily
  # on modern systems)
  #sudo smem -llv 
  # unmount all encrypted paritions(clear them from memory, so they can't be
  # recovered with a cold boot attack)
  sudo umount -f /dev/mapper/udisks* &> /dev/null
  sudo cryptsetup luksClose /dev/mapper/udisks* &> /dev/null
  #zuluMount -u #yeah that doesn't work
  # get the disk size, copy the needed binaries to ram based tmpfs on /tmp,
  # and then chmod them SUID so they run as root.
  DISK_SIZE=$(sudo sfdisk -s ${BOOTDEV})
  sudo cp /var/emergency_bin/pv /tmp/emergency_bin/pv
  sudo chmod 6555 /tmp/emergency_bin/busybox
  sudo chmod 6555 /tmp/emergency_bin/pv
  # wipe the headers off all the paritions one by one BEFORE the zero fill,
  # in case the proccess is interupted encrypted paritions are not recoverable.
  wipe_part_headers
  # Once you see the message below on the screen, you can walk away safely,
  # and all user data is unrecoverable. please note the time on the progress
  # bar.
  echo "Please Stand By, Machine Will Reboot Upon Completion"
  #unset path variable. just because.
  PATH=""
  # now we fill $BOOTDEV with zeros. $BOOTDEV is determined from checking
  # /boot's mount point
  ( /tmp/emergency_bin/busybox dd if=$FILL_SRC bs=128k 2> /dev/null | /tmp/emergency_bin/pv -pet -B 128k -s ${DISK_SIZE}k | /tmp/emergency_bin/busybox dd of=${BOOTDEV} bs=128k 2> /dev/null; /tmp/emergency_bin/busybox sync )
  finale
}

finale() {
  # Reformat the disk with an MBR and a blank FAT32 partition. There is
  # plausable deniability Ninja OS was ever on the disk to begin with.
  # It will look like yet another blank USB Drive
  fdisk_final
  /tmp/emergency_bin/busybox mkfs.vfat ${BOOTDEV}
  /tmp/emergency_bin/busybox sync
  # reboot system when we are done. the "&" makes sure that reboot won't catch
  # an interrupt from the console by running the reboot in the background.
  /tmp/emergency_bin/busybox reboot -f &
  # backstop to make the sure that this script won't return the user to an
  # interactive shell, while waiting for reboot.
  while true ;do
    /tmp/emergency_bin/busybox sleep 2
  done
}

fdisk_final() {
/tmp/emergency_bin/busybox fdisk ${BOOTDEV} &> /dev/null << EOF
n
p
1


w
EOF
}
sd_abort() {
  echo "¡Self Destruct/Zeroize Mode Aborted!"
  sudo rm -f /etc/passwd.bak 2> /dev/null
  tput sgr0
  exit 1
}

# Should be self explanitory, give the user an option to abort. Flash in red and
# orange so they get the message something dangerous is about to happen.
set_background() {
  # White text on a red background
  tput setab 1
  tput setaf 8
  tput bold
}
sd_banner() {
  cat << EOF

	${GREY}+${BRIGHT_YELLOW}---${BRIGHT_WHITE}NINJA ${BRIGHT_YELLOW}SELF ${GREY}DESTRUCT${BRIGHT_YELLOW}---${GREY}+${BRIGHT_WHITE}"
	SELF DESTRUCT/ZEROIZE: ACTIVATED
¡¡¡This script will wipe all data from the entire drive to include the operating system and all user data!!!
EOF
}

interactive_mode() {
  # First stage of the script, we are called from tty1
  set_background
  sd_banner
  # If --noconfirm is not set, ask.
  if [ $NOCONFIRM == "yes" ];then
      SURE="y"
  else
      read -N 1 -p "ARE YOU SURE (yes/no)?" SURE
      SURE=${SURE,,}
  fi
  if [ "${SURE}" == "y" ] ;then
    sudo rm -f $HOME/.bash_profile
    cp $0 $HOME/.bash_profile
    # now lets close all logins and relogin to our new .bash_profile
    # script.
    if [[ $(tty) == /dev/tty? ]];then
      tput sgr0
      pkill X
      kill -HUP $(pgrep -s 0 -o)
     elif [[ $(tty) == /dev/pts/* ]];then
      pkill X
    fi
   else
    # Cat stepped on keyboard again? no problem.
    sd_abort
  fi
}

cmdline_check(){
  #check for options in /proc/cmdline
  set $CMDLINE
  while [ ! -z "$1" ];do
    case "$1" in
      selfdestruct|zeroize|zzz)
        NOCONFIRM="yes"
        BOOTMODE="yes"
        ;;
      *)
        #catch all for words we don't care about
        true
        ;;
    esac
    shift
  done   
}

main() {
  trap "sd_abort" SIGINT SIGTERM
  # check the kernel command line
  cmdline_check
  if [[ ${@} == *--noconfirm* ]];then
    NOCONFIRM="yes"
  fi
  #lowercase sanitation.
  NOCONFIRM=${NOCONFIRM,,}
  GUI=${GUI,,}

  # Lets check how this script is run. It is a three stage script, with three
  # possible start states, and one possible end state.

  #If run from the command line
  [ $BOOTMODE == "yes" ] && scrub_disk

  # Normally, the XFCE desktop is run on virtual terminal 1, started via
  # .bash_profile, which in turn is started by autologon from the new systemd
  # getty. Since we count on autologin on TTY1 being a constant, we can use it
  # in the script. If XFCE is exited, the system will log TTY1, and then
  # re-trigger auto login. To determine where we are in the proccess, we check
  # the TTY to determine where we are in the sequence.
  if [[ "$(tty)" == "/dev/tty1" || ${NOCONFIRM} == "yes" ]];then
    # This is step 2. We assume at this point, we are logging back in
    # because we assume step one completed successfully. at some point we'll
    # do better checking.
    scrub_disk
   else
    # step one, make sure we know what we are doing.
    interactive_mode
  fi
}

main "${@}"
