#!/bin/bash
. ./usr/share/scripts/liveos_boilerplate.sh
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script tries to repair software damage to the outer part of the Live OS that might have been caused by tampering and/or malware. Try running this if "integrity_check" comes back with failures"
OK_COLOR="$(tput bold)$(tput setaf 6)OK! $(tput sgr0)"
FAIL_COLOR="$(tput bold)$(tput setaf 1)!FAILS! $(tput sgr0)"
EXIT=0

echo "$(tput bold) $(tput setaf 6) --+$(tput setaf 7)$OSNAME Integrity Fix Script$(tput setaf 6)+-- $(tput sgr0 )"

#remount /boot read/write so we can overwrite /boot
sudo mount -o rw,remount /boot
if [ $? -eq 0 ];then
    echo "Remounting /boot read-write		${OK_COLOR} "
  else
    echo "Remounting /boot read-write		${FAIL_COLOR} "
    EXIT=$(($EXIT + 1))
fi

#re install extlinux bootloader.
sudo syslinux-install_update -i -a -m
if [ $? -eq 0 ];then
    echo "Re-installing Bootloader		${OK_COLOR} "
  else
    echo "Re-installing Bootloader		${FAIL_COLOR} "
    EXIT=$(($EXIT + 1))
fi

#recopy the boot menu background
sudo cp -rf /usr/share/images/ninjaboot.jpg /boot/isolinux/ninjaboot.jpg
if [ $? -eq 0 ];then
    echo "Copying Bootloader Background		${OK_COLOR} "
  else
    echo "Copying Bootloader Background		${FAIL_COLOR} "
    EXIT=$(($EXIT + 1))
fi

#remake kernel initcpio
sudo mkinitpcio -p linux-aufs_friendly
if [ $? -eq 0 ];then
    echo "Generating Kernel Image		${OK_COLOR} "
  else
    echo "Generating Kernel Image		${FAIL_COLOR} "
    EXIT=$(($EXIT + 1))
fi

#remount /boot read only.
sudo mount -o ro,remount /boot
if [ $? -eq 0 ];then
    echo "Remounting /boot Read-Only		${OK_COLOR} "
  else
    echo "Remounting /boot Read-Only		${FAIL_COLOR} "
    EXIT=$(($EXIT + 1))
fi
echo " "

if [ "$EXIT" -eq "0" ];then
  echo "$(tput bold)$(tput setaf 6)OK!$(tput sgr0) - Important System files have been restored or regenerated, reboot and run \"integrity_check\" on the terminal again to verify they have been fixed"
  exit 0
 else
  echo "$(tput bold)$(tput setaf 1)!FAIL!:$(tput sgr0) - A subcomponent threw an error code. Please see check the above statements and/or try again."
  exit $EXIT
fi
