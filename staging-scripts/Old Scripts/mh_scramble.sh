#!/bin/bash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#   Mac & Host Scramble. This script Randomizes the system hostname and the MAC addresses of all detected Ethernet inferfaces. Detects interface type instead of guessing via naming scheme.

#Sets the source of random data for ethernet addresses.
RAND_SRC="/dev/urandom"

#The file with a list of known ethernet vendor bytes. Used with the --use-vendor-bytes option.
MAC_LIST="/usr/share/eth_vendors.txt"

#If the least signifigant bit in the first byte is odd, the address is an ethernet multi-cast address. For those binary impared it means in the first set of numbers, if the second number is odd, its multicast. Multicast addresses cannot be used. This array lists all odd numbers 1-15 in hexadecimal. This is used in making a random Vendor ID.
MAC_MULTICAST="1 3 5 7 9 b d f"
#the pool is where we keep hexdec numbers for making MAC addresses
POOL=""
RESCRAMBLE="FALSE"
VIDBYTES="FALSE"

#makes a new mac address from scratch, grabs some random data, gets hexdecimal from hashing with md5, and then gets the first 12 numbers as a result into six groups of two, into the variables $a1-$a6
base_mac(){
    POOL=$( head -n128 < $RAND_SRC |md5sum | cut -d " " -f 1 )
    a1=${POOL:0:2};a2=${POOL:2:2};a3=${POOL:4:2};a4=${POOL:6:2};a5=${POOL:8:2};a6=${POOL:10:2}
}
#checks to see if the first byte($a1) would result in a multicast address. If so get a new random first byte
check_fix_multicast() {
    local a1_pool=$( head -n32 < $RAND_SRC |md5sum | cut -d " " -f 1 )
    while [[ "$MAC_MULTICAST" == *${a1:1:1}* ]];do
        local position=$(($RANDOM / 1093))
        a1=${a1_pool:$position:2}
    done
}
# 00:00:00:00:00:00 and FF:FF:FF:FF:FF:FF are reserved for network and broadcast addressing respectively. They may not be used. In the event they are, we start over.
check_broadcast(){
    while [ "$a1:$a2:$a3:$a4:$a5:$a6" == "00:00:00:00:00:00" ] || [ "$a1:$a2:$a3:$a4:$a5:$a6" == "ff:ff:ff:ff:ff:ff" ];do
        base_mac
    done
}
#Generates a new mac address using the subroutines above. Completely Random vendor ID.
new_mac_random(){
   base_mac
   check_broadcast
   check_fix_multicast
   echo "$a1:$a2:$a3:$a4:$a5:$a6"
}
#generates a new mac address using vendor bytes read from a file. Should be less suspicous
new_mac_vid(){
    FINAL_MAC=""
    ##get the first three vendor bytes from reading from a pre-made list.
    #only works with GNU
    VENDOR_MAC=$(shuf "${MAC_LIST}" | cut -d "	" -f 1 | head -n 1)

    #Now generate the device bytes at random
    POOL=$( head -n128 < $RAND_SRC |md5sum | cut -d " " -f 1 )
    a1=${POOL:0:2};a2=${POOL:4:2};a3=${POOL:8:2}
    #Assemble the final mac address from the generated device bits, and the vendor ID.
    FINAL_MAC=${VENDOR_MAC}:${a1}:${a2}:${a3}
    #now print the results
    echo $FINAL_MAC

}
#help, synatx, and switching.
if [[ "${@}" = *--rescramble* ]];then
    RESCRAMBLE="TRUE"
fi
if [[ "${@}" = *--use-vendor-bytes* ]];then
    VIDBYTES="TRUE"
fi

#Banner at the top.
echo $(tput bold) $(tput setaf 6) --+$(tput setaf 7)MAC and Host Scramble$(tput setaf 6)+-- $(tput sgr0 )

#now we fill a list of all network interfaces into $int_all
INT_ALL=$(ifconfig -a -s|tail -n +2 |cut -d " " -f 1)
#now we make a blank list of proccessed interfaces to be filled in later.
INT_LIST=""
#we now check all interfaces listed in $int_all to see if they are Ethernet, and if they are, they get added to $int_list
for iface in $INT_ALL;do
    if [ ! -z "$(ifconfig $iface | grep -i ether)" ];then
        INT_LIST="$INT_LIST $iface"
    fi
done

#Get a total count to tell the user later.
ETHTOTAL=$(echo $INT_LIST|wc -w)

#lets scramble the MAC addresses of all ethernet NICs.
for iface in $INT_LIST;do
    #If the --use-vendor-bytes was typed on the command line, run new_mac_vid, otherwise run new_mac_random.
    if [ "${VIDBYTES}" == "TRUE" ];then
        newmac=$( new_mac_vid )
    else
        newmac=$( new_mac_random )
    fi
    #Once we've gotten the new mac address for the interface, set it, bring the interface down, set the MAC, bring it back up, then tell the user.
    ifconfig $iface down
    ifconfig $iface hw ether $newmac
    ifconfig $iface up
    echo "$(tput bold)		$iface $(tput sgr0 )"
    echo "${iface}: changed mac to $newmac"
    #save the MAC for later, so we can cross refrence what the MAC is supposed to be if another program changes the mac, we can keep it consistant until we decide to change it again.
    echo "$newmac" > "/var/interface/${iface}"
done

#resets /etc/machine-id, used by udev to "identify machines on networks with changing MAC addresses". I do say good sir!
chmod 644 /etc/machine-id
head -n128 < $RAND_SRC |md5sum |cut -d ' ' -f 1 > /etc/machine-id
chmod 444 /etc/machine-id

#now we make a new hostname, lets use apg(automated password generator), because it makes pronouncable (and random) names. Now with more systemd
newhost=$(apg -a 0 -n 1 -m 4 -x 10 -M nc -c P34nU7w4a4S5Lt3D -q -E \!\@\#\$\%\^\&\*\(\)\"\' )
# Now lets set the new hostname.
hostname $newhost
#Now we make a new /etc/hosts file for our new hostname.(overwrites old one)
cat /etc/hosts.head > /etc/hosts
cat >> "/etc/hosts" << EOF
echo 127.0.0.1		localhost.localdomain	localhost $newhost
echo ::1		localhost.localdomain	localhost $newhost

EOF
# with the introduction of systemd, /etc/hostname now works on larch like every other UNIX system.
echo $newhost > /etc/hostname

#And we are done, give the user a summary.
echo "mh_scramble: changed hostname to $(tput bold)${newhost}$(tput sgr0 ) found $ETHTOTAL ethernet devices. Scrambled /etc/machine-id. Lasts until reboot."

#if this script was called with --rescramble, lets kill X which will log the system out, which will re-trigger the autologin which is neccary because XFCE freaks out and stops working if the system hostname changes while running.
if [ "$RESCRAMBLE" == "TRUE" ];then
    pkill X
fi
