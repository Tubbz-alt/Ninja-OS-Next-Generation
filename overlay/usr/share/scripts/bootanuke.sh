#!/usr/bin/ash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#                  +Ninja Boot'n'Nuke (nban)+
#  Inspired by Darik's Boot'n'Nuke, but implemented soley as an Arch Linux
#  mkinitcpio script.
#
#  Nban in turn, is the core of the "Ninja Shiruken", with the addition of a
#  syslinux bootloader, is a single use(read self wiping) nban flash drive,
#  which can be quickly spawned by Ninja OS.

# you can test this with mkinitcpio -p nban in ninja os, and then booting with
# initrd=nban.img at the kernel command line. Careful, this will wipe all data
# from all attached storage media.

FILL_SRC=/dev/zero
RAND_SRC=/dev/urandom
PIDS=""

## As adapted from self destruct.
nuke_dev() {
  # Erase a block device. $1 is the device name, $2 is the type, either disk
  # or flash. This is used for wipe_part_headers() see bellow
  local disk=$1
  local type="$2"
  local size="$(get_size ${disk})"
  # Check if ATA secure erase is supported. If its supported, and disk is
  # available, wipe
  local check="$(check_security_wipe)"
  [ "${check}" == "OK" ] && ssd_secure_erase ${disk} ${size}
  echo "Disk ${disk}(${size}):		Begin Fill..."
  #wipe the partition headers first. Give us the same results as self destruct
  wipe_part_headers ${disk} ${type}
  #now fill the entire disk.
  dd if=${FILL_SRC} of=${disk} bs=128k 2> /dev/null
  sync
  echo "Disk ${disk}(${size}):		Fill Complete!"
  fdisk_final ${disk}
  sync
  echo "Disk ${disk}(${size}):		Done!"
}

wipe_part_headers() {
  # This script wipes partition headers and the boot sector with random as
  # defined in $RAND_SRC. The $1 is the name of the parent block device. $2
  # is the type of device, either "disk" or "flash". This is done because of
  # a discrepency between how the two name partitions.
  local parts=""
  case ${2} in
   disk)
    parts="$(ls ${1}? 2> /dev/null)"
    ;;
   flash)
    parts="$(ls ${1}p? 2> /dev/null)"
    ;;
  esac

  for part in ${parts};do
    dd if=${RAND_SRC} bs=128k count=1 of=${part} 2> /dev/null
    sync
  done
  dd if=${RAND_SRC} bs=128k count=1 of=${1} 2> /dev/null
  sync
}

ssd_secure_erase() {
  # lets get parameters
  local disk=${1}
  local size="${2}"
  local password="p4ssw0rd"
  local exit=0
  # use hdparm to get estimated scrub times.
  local rtime=$(hdparm -I ${disk}|grep SECURITY\ ERASE\ UNIT| cut -d \  -f 1)
  local etime=$(hdparm -I ${disk}|grep SECURITY\ ERASE\ UNIT| cut -d \  -f 6)
  echo "${disk}(${size}): ATA secure_erase support found!, attemping secure_erase."
  # sets a temporary password, which will be overwritten anyway in the wipe
  hdparm --user-master u --security-set-pass "${password}" ${disk}
  exit=$(($exit+$?))
  # do the wipe
  echo "${disk}(${size}):This should take around ${etime}, be patient"
  hdparm --user-master u --security-erase-enhanced "${password}" ${disk}
  exit=$(($exit+$?))
  sync
  [ $exit -eq 0 ] && echo "${disk}(${size}): secure_erase Complete"
  [ $exit -ne 0 ] && echo "${disk}(${size}): secure_erase Failed!"
  return $exit
}
check_security_wipe(){
  # check if we can use ATA secure erase on the disk. $1 is the disk name.
  # This script returns "OK" if all tests pass, or prints an error message if
  # we cannot.
  local disk=$1
  local frozen=$(hdparm -I ${disk} 2> /dev/null | grep -i "frozen" &> /dev/null )
  local support=$(hdparm -I ${disk} 2> /dev/null | grep "SECURITY ERASE UNIT" &> /dev/null )
  if [ "$frozen" != "	not	frozen" ];then
    echo "${disk} is frozen, unfreeze and try again."
   elif [ "${support}" == "${support}x" ];then
    echo "${disk} does not support ATA secure erase, skipping wipe..."
   elif [ ! -b ${disk} ];then
    echo "${disk} is not a block device, cannot ATA secure erase!"
   else
    echo "OK"
  fi
}

get_size() {
    # takes $1 as a block device and returns the size from fdisk.
    dev_size=$(fdisk -l ${1} |head -1 |cut -f 3-4 -d " "|cut -d "," -f 1 )
    if [ "${dev_size}x" = "x" ];then
        echo 0
      else
        echo "${dev_size}"
    fi
}
fdisk_final() {
fdisk ${1} &> /dev/null << EOF
n
p
1


w
EOF
mkfs.vfat ${1}1 &> /dev/null
}

main(){
  # Trap escapes, so this cannot be interupted. This really isn't needed as we
  # don't  have the keyboard drivers in nban anyway
  trap "echo &> /dev/null" 1 2 9 15 17 19 23
  # alternate trap is to reboot on interrupt
  # trap "wait 2;reboot -f" 1 2 9 15 17 19 23

  # wait 2 seconds to give all devices time to initialize
  sleep 2

  ## TODO figure out how to get names of disks past the 26th disk such as
  # /dev/sdaa
  # After Disks have been initalized get names of all disks
  MODERN_DISKS="$(ls /dev/sd? 2> /dev/null)"
  MMC_BLOCK="$(ls /dev/mmcblk? 2> /dev/null)"

  ## Experimental. Extra block device names which may or may not be useful.
  # https://www.kernel.org/doc/Documentation/devices.txt
  # 2 block	Floppy disks
  FLOPPIES="$(ls /dev/fd? 2> /dev/null)"
  # 3 block	First MFM, RLL and IDE hard disk/CD-ROM interface
  OLD_DISKS="$(ls /dev/hd? 2> /dev/null)"
  # 21 block	Acorn MFM hard drive interface
  ACORN_DISKS="$(ls /dev/mfm? 2> /dev/null)"
  # 28 block	ACSI disk (68k/Atari)
  ATARI_HD="$(ls /dev/ad? 2> /dev/null))"
  # 31 block	ROM/flash memory card
  FLASH_ROM="$(ls /dev/rom? 2> /dev/null) $(ls /dev/flash? 2> /dev/null)"
  # 44 block	Flash Translation Layer (FTL) filesystems
  FTL="$(ls /dev/ftl? 2> /dev/null)"
  # 45 block	Parallel port IDE disk devices
  PAR_IDE_HD="$(ls /dev/pd? 2> /dev/null)"
  # 47 block	Parallel port ATAPI disk devices
  PAR_ATAPI_HD="$(ls /dev/pf? 2> /dev/null)"
  # 48 block	Mylex DAC960 PCI RAID controller		+AND+
  MYLEX_RAID="$(ls /dev/rd/c?d? 2> /dev/null)" #note, partitions use p1 like mmcblk
  # 72 block	Compaq Intelligent Drive Array, first controller
  COMPAQ_RAID="$(ls /dev/ida/c?d? 2> /dev/null)" #note, partitions use p1 like mmcblk
  # 80 block	I2O hard disk
  I2O_HD="$(ls /dev/i2o/hd? 2> /dev/null)"
  # 93 block	NAND Flash Translation Layer filesystem
  NAND_FTL="$(ls /dev/nftl? 2> /dev/null)"
  # 94 block	IBM S/390 DASD block storage
  S390_BLOCK="$(ls /dev/dasd? 2> /dev/null)"
  # 96 block	Inverse NAND Flash Translation Layer
  INVNAND_FTL="$(ls /dev/inftl? 2> /dev/null)"
  # 101 block	AMI HyperDisk RAID controller
  HYPERDISK_RAID="$(ls /dev/amiraid/ar? 2> /dev/null)" #note, partitions use p1 like mmcblk
  # 104 block	Compaq Next Generation Drive Array, first controller
  COMPAQ_NG_RAID="$(ls /dev/cciss/c?d? 2> /dev/null)" #note, partitions use p1 like mmcblk
  # 112 block	IBM iSeries virtual disk
  ISERIES_VIRT="$(ls /dev/iseries/vd? 2> /dev/null)"
  # 114 block       IDE BIOS powered software RAID interfaces such as the
  #		  Promise Fastrak
  IDE_SOFT_RAID="$(ls /dev/ataraid/d? 2> /dev/null)" #note, partitions use p1 like mmcblk
  # 116 block       MicroMemory battery backed RAM adapter (NVRAM)
  MICROMEM_RAM="$(ls /dev/umem/d? 2> /dev/null)" #note, partitions use p1 like mmcblk
  # 153 block	Enhanced Metadisk RAID (EMD) storage units
  EMD_RAID="$(ls /dev/emd/? 2> /dev/null)" #note, partitions use p1 like mmcblk
  # 160 block       Carmel 8-port SATA Disks on First Controller
  CARMEL_RAID="$(ls /dev/carmel/? 2> /dev/null)" #note, partitions use p1 like mmcblk
  # 180 block	USB block devices
  USB_HD="$(ls /dev/ub? 2> /dev/null)"
  # 202 block	Xen Virtual Block Device
  XEN_HD="$(ls /dev/xvd? 2> /dev/null)"

  # These are for block devices that use /dev/AAAXY format for the partition. Just
  # like /dev/sd* "scsi/sata/hdparm/etc..."
  REGDEVS="${MODERN_DISKS} ${FLOPPYS} ${XEN_HD} ${OLD_DISKS}"

  # devices that mark parition /dev/AAAXpY format.
  P1DEVS="${MMC_BLOCK}"

  set ${REGDEVS} ${P1DEVS}
  NUMDEVS=${#}
  #tell the user what we are doing.
  echo "		+++Ninja Boot'n'Nuke+++"
  echo -n "Found ${NUMDEVS} device(s):"
  for DEVICE in ${@};do
      SIZE=$(get_size ${DEVICE})
      echo -n " ${DEVICE}(${SIZE})"
  done
  unset SIZE
  echo " "; echo " "

  # Now scrub the devices, in the background spawning a new shell for every device
  # (work in parallel)
  for DEVICE in ${REGDEVS} ;do
      ( nuke_dev ${DEVICE} disk ) &
      PIDS="$PIDS $!"
  done

  for DEVICE in ${P1DEVS};do
      ( nuke_dev ${DEVICE} flash ) &
      PIDS="$PIDS $!"
  done

  #Wait for all the wipes to be done
  wait ${PIDS}
  echo "Complete! Rebooting"
  sleep 1

  # when we are all done reboot
  reboot -f &
  #backstop to prevent a return to shell pending reboot.
  while true ;do
      sleep 2
  done
}

main ${@}
