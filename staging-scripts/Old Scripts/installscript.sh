#!/bin/sh
#
#  Written for the Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# run this script AFTER installing base system with larch.

# This script is now depreciated. the contents have been moved into an arch linux package file.
echo "larch install script for NinjaOS. Make sure you run this after the installation phase of larch, and change LIVECD= as necessary"
#MAKE SURE THIS IS POINTED TO THE ROOT OF THE LIVE CD!!!!!!
LIVECD=$HOME/Documents/larch_build

#after pointing LIVECD to the appropriate location, comment these two lines out
echo "EDIT THIS SCRIPT BEFORE RUNNING"
exit 1

#for some reason the networkmanager installation doesn't do this.
sudo chroot $LIVECD groupadd -r networkmanager && exit
#sudo chroot $LIVECD ln -s /usr/bin/locale-gen /usr/sbin/locale-gen

#PACMAN 4 KEY SUPPORT YARR!!!
sudo mount -o bind /dev "$LIVECD"/dev
sudo chroot $LIVECD /usr/bin/pacman-key --init && exit
sudo chroot $LIVECD /usr/bin/pacman-key --populate archlinux && exit
sudo chroot $LIVECD setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' /usr/bin/dumpcap;exit
sudo chroot $LIVECD setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' /usr/bin/ping;exit
sudo chroot $LIVECD chmod u+s /usr/bin/ping;exit
sudo chroot $LIVECD chmod u+s /usr/bin/ping6;exit
sudo chroot $LIVECD /bin/ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules && exit
sudo chroot $LIVECD /bin/ln -s /usr/share/zoneinfo/Etc/Zulu /etc/localtime && exit
sudo chroot $LIVECD systemctl mask mkinitcpio-generate-shutdown-ramfs.service
sudo umount "$LIVECD"/dev

exit
