#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# Checks system components outside of the squashfile for signs of damage and/or
# tampering. Checks against file signatures with GPG and the Ninja OS signing
# key.

# Every time you build you need to manually sign: mods.sqf, system.sqf,
# ldlinux.sys, and larch.img and put them in /boot/sigs/ in the root overlay

source /usr/share/scripts/liveos_lib.sh
#override the boilerplate because we need static versioning
source /var/liveos_version.conf
#colors for pass and fail
OK_COLOR="${BRIGHT_CYAN}OK!${NOCOLOR}"
FAIL_COLOR="${BRIGHT_RED}!FAILS!${NOCOLOR}"

declare -i EXIT=0

print_comp_status() {
    # handles the result of each code, run this after each gpg. $1 is the exit
    # status, $2 is the item name, $3 is the spacing.
    local -i exit_code=$1
    local item_name="$2"
    local spacing="$3"
    if [ $exit_code -eq 0 ];then
        echo "${item_name}${spacing}${OK_COLOR}"
      else
        echo "${item_name}${spacing}${FAIL_COLOR}"
        EXIT+=1
        echo "${item_name}:" >> /tmp/int_errors
        cat /tmp/temp_int >> /tmp/int_errors
    fi
}

exit_with_error(){
    # cleanup in case of failure and exit. first parameter is exit message.
    # second is a message.
    echo "${BRIGHT_RED}${2}${NOCOLOR}" 1>&2
    cleanup
    exit $1
}

message() {
    echo "${BRIGHT}integrity_check${NOCOLOR}:"
}
warn(){
    message "${BRIGHT_YELLOW}WARNING!${NOCOLOR} $@" 1>&2
}
exit_with_error() {
   message "${BRIGHTRED}ERROR:${NOCOLOR} $2" 1>&2
   exit $1
}

cleanup() {
    local -i exit=0
    rm -f /tmp/int_errors &> /dev/null
    exit+=$?
    rm -f /tmp/temp_int &> /dev/null
    exit+=$?
    rm -f /tmp/bootsectorimage &> /dev/null
    exit+=$?
    return $exit
}

gpg_check(){
    # use as gpg_check <sig_file> <file_to_check>
    gpg --no-default-keyring --keyring /usr/share/ninja_pubring.gpg --verify "$@" 2> /tmp/temp_int
    return $?
}

echo "${BRIGHT_CYAN}  --+$(tput setaf 7)$OSNAME Integrity Check${BRIGHT_CYAN}+-- ${NOCOLOR}"

trap "exit_with_error 1 'Aborted!' " SIGINT SIGTERM #exit cleanly with an abort

# check the to see if the key in the config matches up to what is being used. If
# not print the color in red.
KEY_COLOR=${BRIGHT_GREEN}
[[ $(gpg_check_key) == "FALSE" ]] && KEY_COLOR=${BRIGHT_RED}
echo "    GPG Key: ${KEY_COLOR}${GPG_KEYNAME}${NOCOLOR}"
echo ""

# int_errors is a running log of fail messages from GPG, while temp_init is the
# current error message. we display these at the end to the user
touch /tmp/int_errors
touch /tmp/temp_int

#first we check the boot sector
sudo dd if=${BOOTDEV} of=/tmp/bootsectorimage bs=440 count=1 > /dev/null 2>&1
gpg_check /var/lib/misc/bootsector.sig /tmp/bootsectorimage
print_comp_status $? "Boot Sector" "				"
sudo rm -f /tmp/bootsectorimage

# Test all the bootloader files
declare -i MENU_EXIT=0
BOOTLOADER_FILES=(vesamenu.c32 chain.c32 libutil.c32 libcom32.c32 reboot.c32 hdt.c32 libmenu.c32 libgpl.c32)
for file in "${BOOTLOADER_FILES[@]}";do
    gpg --no-default-keyring --keyring /usr/share/ninja_pubring.gpg --verify /var/lib/misc/${file}.sig /boot/isolinux/${file} 2>> /tmp/temp_int
    MENU_EXIT+=$?
done
print_comp_status $MENU_EXIT "Boot Menu" "				"

# Now lets check the kernel
KERNELNAME=$(cat /boot/kernelname)
gpg_check /var/lib/misc/kernel.sig /boot/${KERNELNAME}
print_comp_status $? "KERNEL: ${KERNELNAME}" "	"

# check intel microcode initial ramdisk, loaded beforehand.
gpg_check /var/lib/misc/intel-ucode.img.sig /boot/intel-ucode.img
print_comp_status $? "Intel microcode" "				"

#make sure the version file hasn't been tampered with
gpg_check /var/lib/misc/liveos_version.conf.sig /var/liveos_version.conf
print_comp_status $? "Version File" "				"

# Once we can confirm LIVEOS_VERSION hasn't been tampered with, we can trust the
# SHA256 sum
BACKGROUND_CURRENT=$(sha256sum ${BOOT_BACKGROUND} | cut -d " " -f 1)
if [ ${BACKGROUND_CURRENT} == ${BACKGROUND_SHA256} ]; then
  echo "+++ Boot Menu Background File		${OK_COLOR}"
 else
  echo "+++ Boot Menu Background File		${FAIL_COLOR}"
  EXIT+=1
fi

echo "----------------"
# Below this line are files checked from /boot/sigs, a read-write area outside
# the main body of the squashfile(and thus easily changable). This is presumed
# to be safe, because they are checked against a public key that *is* conainted
# in the squashfile. This would not be acceptable with the old SHA256 method.

# Initial Ramdisk
gpg_check /boot/sigs/larch.img.sig /boot/larch.img
print_comp_status $? "Initial Ramdisk" "				"

# now the bootloader in /boot/isolinux/ldlinux.sys
gpg_check /boot/sigs/ldlinux.sys.sig /boot/isolinux/ldlinux.sys
print_comp_status $? "Boot Loader" "				"

# mods.sqf
gpg_check /boot/sigs/mods.sqf.sig /.livesys/medium/larch/mods.sqf
print_comp_status $? "Modules Squash File" "			"

# system.sqf - This is where the OS is. This takes a long time and is very
# important
echo "Checking Main System SquashFS file, this might take a while..."
gpg_check /boot/sigs/system.sqf.sig /.livesys/medium/larch/system.sqf
print_comp_status $? "Main Squash File" "			"

### Now lets exit, and give the user a summary of errors found
# Exit color is teal, except if there is an error, then its red
EXIT_COLOR=${BRIGHT_CYAN}
[ $EXIT -ne 0 ] && EXIT_COLOR=${BRIGHT_RED}

cat <<- EOF

This disk identifies itself as ${BRIGHT}${OSNAME} ${OSVERSION}(${OSARCH})${NOCOLOR}. You should see this name and version number at the boot menu.

	There were ${EXIT_COLOR}${EXIT}${NOCOLOR} failure(s)

Any failures likely indicate either drive damage or tampering, in either case replacing the medium or restoring the system partition from a good back up should be done immediately
EOF
#print error lot at the end
cat /tmp/int_errors
#remove error log
cleanup || warn "could not remove temporary files, you might need to clean them up manually in /tmp"
exit $EXIT
