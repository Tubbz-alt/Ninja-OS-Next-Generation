#!/bin/bash
#
#  Written for the Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#  use as getbshash.sh /dev/sd(abc etc...) Prints the hash of the bootsector.
if  [ -z $1 ] || [ ! -b $1 ]; then
    echo "$(tput bold)getbshash.sh:$(tput sgr0) Invalid block device! see $0 --help"
    exit 1
  elif [ $1 = "--help" ]; then
    echo "$(tput bold)getbshash.sh:$(tput sgr0) This is a shell script that captures a hash sum of the boot sector of a target device. It uses SHA256 at current. use as getbshash.sh \</device/file/path\>"
    echo " "
    echo "	$(tput bold)Usage: $(tput sgr0) getbshash.sh <devicename>"
    exit 1
  else
    sudo dd if=$1 of=/tmp/bootsectorimage bs=440 count=1 > /dev/null 2>&1
    shasum -a 256 /tmp/bootsectorimage | cut -f 1 -d " "
    sudo rm /tmp/bootsectorimage
    exit 0
fi
