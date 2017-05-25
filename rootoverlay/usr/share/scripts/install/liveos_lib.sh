#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# Bash Library to use common LiveOS $VARIABLES in scripts.
# add ". /usr/share/scripts/liveos_lib" to the top of your script.

# Export version

file_help() {
  cat 1>&2 << EOF
	liveos_lib.sh:
This is a bash library that houses common variables and functions. Use by
sourcing this at the top of the script such as

source /usr/share/scripts/liveos_lib.sh

	+=Available functions and Variables:=+

	Versioning:
	Versioning information is sourced from a liveos_version.conf file.
	nominally this is placed in /var/liveos_version.conf. However this can
	be overrridden by local copies either in \$HOME or present directory.

	\$OSNAME	- Name of the Operating System
	\$OSVERSION 	- Version of the operating System
	\$OSSLUG	- is a UNIX santized version of $OSNAME
	\$FORMAT_VER	- version of the format of /var/liveos_version.conf
	\$BOOT_BACKGROUND	- the jpg from the syslinux splash screen
	\$BACKGROUND_SHA256	- hash sum of the background
	\$PART_SIZE	- Parition size in megabytes
	\$LINE5		- vestige from the old /var/LIVEOS_VERSION.TXT file
	\$CONF_KEYNAME	- GPG Keyname as read from the conf file
	\$CONF_KEYSIG	- Full GPG fingerprint as read from the conf file
	\$SCRIPT_NAME	- Name of the originating script, with no path.

	System:
	\$BOOTDEV	- Block device of the drive that the Ninja OS resides on
	\$BOOTPART	- Parition of that drive with /boot, generally the real
			  physical partition with the OS.
	\$CMDLINE	- the contents of /proc/cmdline. Useful for checking
			  boot time options

	gpg_check_key()	- function that checks the gpg key that is used vs gpg
			  key reported by the configuration file. returns 0 for
			  good key, 1 for a bad one.

	read_old_version_file() - function that reads old LIVEOS_VERSION.TXT
				  file
	check_sudo()	- checks if sudo works for granting root access. returns
			  "TRUE" or "FALSE"

	Coloring:
	Insert terminal coloring into printed text. should be self explanitory
	\$BRIGHT_GREEN
	\$BRIGHT_YELLOW
	\$BRIGHT_RED
	\$BRIGHT_CYAN	- thats light blue
	\$BRIGHT		- bold
	\$GREY
	\$BRIGHT_WHITE
        \$NOCOLOR	- resets all color codes

	GPG:
	Pulls GPG key information from the key used, as opposed to the config
	\$GPG_KEYFILE	- Location of GPG keyring file
	\$GPG_KEYNAME	- GPG public key of the OS
	\$GPG_FINGERPRINT- Prints the full GPG fingerprint of the OS

EOF
exit 1
}

exit_with_error(){
  echo "liveos_lib.sh: ERROR ${2}"
  exit $1
}

# the new version file is a bash script that can be sourced, good riddence.

## VARS ##
VERSION_FILE="${PWD}/liveos_version.conf"
[ -f "../liveos_version.conf" ] && VERSION_FILE="../liveos_version.conf"
[ ! -f "${VERSION_FILE}" ] && exit_with_error 1 "Cannot Find Version Index"

source "$VERSION_FILE" || exit_with_error 1 "Cannot Read Version Index"

# the slug is a sanitized for unix name space version of name. lowercase and no
# spaces
OSSLUG=${OSNAME,,}
OSSLUG=${OSSLUG//[[:blank:]]/}

SCRIPT_NAME=$(basename "${0}")

#contents of the kernel command line, i.e. from the boot loader
CMDLINE=$(cat /proc/cmdline)

#GPG stuff.
GPG_KEYRING="./ninja_pubring.gpg"
GPG_KEYNAME=$(gpg --no-default-keyring --keyring "${GPG_KEYRING}" --fingerprint| awk 'NR==4{print $9$10}')
GPG_FINGERPRINT=$(gpg --no-default-keyring --keyring "${GPG_KEYRING}" --list-keys |awk 'NR==4{print $1}')

#pretty terminal colors
BRIGHT_RED=$(tput setaf 1;tput bold)
BRIGHT_GREEN=$(tput setaf 2;tput bold)
BRIGHT_YELLOW=$(tput setaf 3;tput bold)
BRIGHT_CYAN=$(tput setaf 6;tput bold)
GREY=$(tput bold;tput setaf 0)
BRIGHT_WHITE=$(tput bold;tput setaf 7)
BRIGHT=$(tput bold)
NOCOLOR=$(tput sgr0)


### Functions ###

# check if GPG key matches key in configuration file, if so, return "TRUE" else
# return false
gpg_check_key() {
  if [[ $CONF_KEYNAME == $GPG_KEYNAME && $CONF_KEYSIG == $GPG_FINGERPRINT ]];then
    echo "TRUE"
   else
    echo "FALSE"
  fi
}

#read the pre 0.11.x LIVEOS_VERSION.TXT
read_old_version_file(){
  local version_file="/var/LIVEOS_VERSION.TXT"
  [ -f "${PWD}/LIVEOS_VERSION.TXT" ] && version_file="${PWD}/LIVEOS_VERSION.TXT"
  echo OSNAME=$(awk 'NR==1{print $1}' "$version_file")
  echo OSVERSION=$(awk 'NR==1{print $2}' "$version_file")
  echo BACKGROUND=$(awk 'NR==2{print $1}' "$version_file")
  echo BACKGROUND_SHA256=$(awk 'NR==2{print $2}' "$version_file")
  echo LINE5=$(awk 'NR==5' "$version_file")
  OLD_VERSION_FILE=${version_file}
}

check_sudo() {
  # test should equal "root"
  local test=""
  test=$(sudo whoami 2> /dev/null )
  if [ ${test} == "root" ];then
    echo "TRUE"
   else
    echo "FALSE"
  fi
}

