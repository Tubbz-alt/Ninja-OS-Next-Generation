#!/usr/bin/env python3
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#   Mac & Host Scramble. This script Randomizes the system hostname and
# the MAC addresses of all detected Ethernet inferfaces. Detects interface
# type instead of guessing via naming scheme.
# This is a python re-write of the original BASH script
#
# needs python-netifaces
 
######CONFIG####################################################################
class config:                                                                  #
#The file with a list of known ethernet vendor bytes. Used with the            #
# --use-vendor-bytes option.                                                   #
    MAC_LIST      = "/usr/share/eth_vendors.txt"                               #
# Use NetworkManager to set the mac address(experimental)                      #
    USE_NM        = False                                                      #
# Use NetworkManager's native mac scrambling. Every new connection gets random #
# MAC                                                                          #
    USE_NM_RNDMAC = False                                                      #
# Use ifconfig to set the mac address - legacy, may not work with nm anymore   #
    USE_IFCONFIG  = True                                                       #
################################################################################

import random
import subprocess
import sys
import os

#check if netifaces is installed
try:
    import netifaces
except:
    print("mh_scramble.py: python-netifaces is not installed, exiting")
    sys.exit(1)

class colors:
    '''pretty terminal colors'''
    reset='\033[0m'
    bold='\033[01m'
    red='\033[31m'
    cyan='\033[36m'
    yellow='\033[93m'
    lightgrey='\033[37m'
    darkgrey='\033[90m'
    lightblue='\033[94m'
    lightcyan='\033[96m'

 
def gen_mac_random():
    '''generates a completely random mac'''
    # An odd number in the first Digit is multi-cast and invalid for
    # assignment
    a1 = random.choice("0123456789abcdef") + random.choice("02468ace")
    a2 = random.choice("0123456789abcdef") + random.choice("0123456789abcdef")
    a3 = random.choice("0123456789abcdef") + random.choice("0123456789abcdef")
    a4 = random.choice("0123456789abcdef") + random.choice("0123456789abcdef")
    a5 = random.choice("0123456789abcdef") + random.choice("0123456789abcdef")
    a6 = random.choice("0123456789abcdef") + random.choice("0123456789abcdef")
    
    output = a1 + ":" + a2 + ":" + a3 + ":" + a4 + ":" + a5 + ":" + a6 
    return(output)

def strip_comments(inList):
    '''Strips out lines that start with # from a list that contains a dump of a file. please note it does not work with lines that have comments at the end.'''
    fileLines = []
    for line in inList:
        li=line.strip()
        li=li.strip('\n')
        if not li.startswith("#") and li != "":
            fileLines.append(line.split("#")[0])
    return fileLines

def bin2txt(in_text):
    '''Convert system command output to usable string'''
    output = str(in_text.strip())
    output = output.lstrip("b")
    output = output.strip("\'")
    return output
 
def gen_mac_vid(vid_file):
    '''generates a mac with vendor bytes read from a list'''
    import random
    try:
        inFile    = open(vid_file,"r")
        fileLines = inFile.readlines()
        inFile.close()
    except:
        exit_with_error(1,"Cannot read VID file")
        
    #now with proper input santitization
    fileLines = strip_comments(fileLines)

    #get a random line from the file
    output = fileLines[ random.randrange( len(fileLines) ) ]
    #get the MAC address from the line
    output = output.split()[0]
    
    #and now for some random device bits
    a4 = random.choice("0123456789abcdef") + random.choice("0123456789abcdef")
    a5 = random.choice("0123456789abcdef") + random.choice("0123456789abcdef")
    a6 = random.choice("0123456789abcdef") + random.choice("0123456789abcdef")
    output = output + ":" + a4 + ":" + a5 + ":" + a6 
    return(output)
    
def get_eth_interfaces():
    '''return all ethernet interfaces detected in a list'''
    #all interfaces
    int_list = netifaces.interfaces()
    #remove the loopback
    del( int_list[ int_list.index('lo') ] )
    #now make a list with only ethernet addresses
    eth_list = []
    for iface in int_list:
        if netifaces.AF_LINK in netifaces.ifaddresses(iface):
            eth_list.append(iface)
    return eth_list

def random_hostname():
    try:
        new_hostname = str( subprocess.check_output(['apg', '-a0', '-n1', '-m4', '-x10', '-Mnc', '-cP34nU7w4a4S5Lt3D', '-q']) )
        new_hostname = new_hostname.strip("\\n\'")
        new_hostname = new_hostname.strip("b\'")
    except FileNotFoundError:
        exit_with_error(1,"APG Binary Not Found")
    return new_hostname

def random_machine_id():
    output = ""
    for i in range(32):
        output += random.choice("0123456789abcdef")
    return output

def message(message):
    print(colors.bold + "mh_scramble.sh: " + colors.reset + message)

def submsg(message):
    print("\t       " + message)

def exit_with_error(exit,message):
    print(colors.bold + "mh_scramble.sh: " + colors.red +" ¡ERROR!: " + colors.reset + message, file=sys.stderr)
    sys.exit(exit)

def warn(message):
    print(colors.bold + "mh_scramble.sh: " + colors.yellow +"¡WARN!: " + colors.reset + message, file=sys.stderr)
    return

def main():
    '''main program'''
    #start with the argument parser
    import argparse
    parser = argparse.ArgumentParser(description='''MAC and HOST scramble: Scrambles Ethernet MAC addresses, system hostname, and /etc/machine-id''')
    parser.add_argument('-s','--rescramble',help="Repeat the proccess after boot, restarts X when complete",action="store_true")
    parser.add_argument('-r','--random_vid',help="Don't Read VID bytes from file, use completely random VID bytes",action="store_true")

    depreciated = parser.add_argument_group("Depreciated","Kept for backwards compatibility, do not use")
    depreciated.add_argument('--use-vendor-bytes',help="Now the default option, depreciated, do not use",action="store_true")
    args = parser.parse_args()

    #get interface names
    iface_list      = get_eth_interfaces()
    iface_count     = len(iface_list)

    print( colors.bold + colors.cyan + "--+" + colors.lightgrey + " Mac and Host Scramble " + colors.cyan + "+--" + colors.reset)
    
    #make new MAC addresses for each interface
    iface_errors = 0
    # modern versions of NetworkManager have a build in scrambler, if configured
    # use this instead. It will give every new connection a random MAC address
    if config.USE_NM_RNDMAC == True and args.rescramble != True:
        outfile = open("/etc/NetworkManager/NetworkManager.conf","a")
        outfile.write('''
[connection]
ethernet.cloned-mac-address=random
wifi.cloned-mac-address=random

''')
        outfile.close()
    for iface in iface_list:
        newmac       = ""
        conname      = ""
        cmdline      = ""
        if args.random_vid == True:
            newmac = gen_mac_random()
        else:
            newmac = gen_mac_vid(config.MAC_LIST)
        # Save the MAC for later, in case it gets reset.
        outfile = open("/var/interface/"+iface,"w")
        outfile.write(newmac)
        outfile.close()
        if config.USE_NM == True:
            #new NetworkManager based mac address scrambling, experimental
            try:
            #    #get the name of the connection from the name of the interface
            #    conname = subprocess.check_output("nmcli -t --fields name,device connection|grep " + iface,shell=True)
            #    conname = bin2txt(conname)
            #    conname = conname.split(":")[0]
            #    conname = "\'" + conname + "\'"
                #Now get the type
                contype = subprocess.check_output("nmcli -t --fields type,device device|grep " + iface,shell=True)
                contype = bin2txt(contype)
                contype = contype.split(":")[0]
                contype = "\'" + contype + "\'"
            except:
                warn("Cannot get interface type for " + iface + ", skipping...")
                continue
            # Now set MAC address
            #cmdline2 = "nmcli connection modify " + conname + " " + contype + ".cloned-mac-address " + newmac
            cmdline = "nmcli device modify " + iface + " " + contype + ".cloned-mac-address " + newmac
            try:
                subprocess.check_call(cmdline,shell=True)
            except:
                warn("Cannot set MAC for " + iface + " using networkmanager.")
                iface_errors += 1
                continue
        if config.USE_IFCONFIG == True:
            try:
                subprocess.check_call("ifconfig " + iface + " down",shell=True)
                subprocess.check_call("ifconfig " + iface + " hw ether " + newmac,shell=True)
                subprocess.check_call("ifconfig " + iface + " up",shell=True)
            except:
                warn("Cannot change MAC for " + iface + " Using ifconfig")
                iface_errors += 1
                continue

        submsg(colors.bold + iface + colors.reset)
        print(iface +": changed mac to " + newmac)
    
    # Resets /etc/machine-id, used by udev to "identify machines on networks
    # with changing MAC addresses". I do say good sir!
    machine_id = random_machine_id()
    os.chmod('/etc/machine-id',644)
    outfile = open('/etc/machine-id',"w")
    outfile.write(machine_id)
    outfile.write("\n")
    outfile.close()
    os.chmod('/etc/machine-id',444)

    #new hostname, we still use APG for pronouncable passwords
    new_hostname = random_hostname()
    #write it to file so it works
    try:
        subprocess.check_call("hostnamectl set-hostname " + new_hostname,shell=True)
    except:
        exit_with_error(1,"Cannot set hostname, root?")
    #write /etc/hosts
    try:
        infile  = open("/etc/hosts.head","r")
        outfile = open("/etc/hosts","w")

        hosts_header = infile.read()
        hosts_text   = '127.0.0.1        localhost.localdomain    localhost ' + new_hostname + '\n'
        hosts_text  += '::1              localhost.localdomain    localhost ' + new_hostname + '\n'
        
        outfile.write(hosts_header+"\n")
        outfile.write(hosts_text)

        infile.close()
        outfile.close()
    except:
        warn("Cannot write to /etc/hosts, you need to manually add the new hostname to 127.0.0.1 in /etc/hosts")

    #Now print message and exit.
    exit_string= "changed hostname to " + colors.bold + new_hostname + colors.reset + ", found " + str(iface_count) + " ethernet interfaces found, " + str(iface_count - iface_errors) + " scrambled. Scrambled /etc/machine-id. Lasts until reboot"
    message(exit_string)
    
    # if this script was called with --rescramble,
    # lets kill X which will log the system out, which will re-trigger the
    # autologin which is necessary because XFCE freaks out and stops working if
    # the system hostname changes while running.
    if args.rescramble == True:
        subprocess.call("pkill X",shell=True)
    if iface_errors > 0:
        submsg(str(iface_errors) + " Interface Errors")
        sys.exit(2)

if __name__ == "__main__":
    main()

