#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#This Script strips metadata from pngfiles using the pngcrush binary.
#
#	Usage:
#	$ pngstrip.sh <filelist>

#pretty terminal colors
BRIGHT_RED=$(tput setaf 1;tput bold)
BRIGHT_GREEN=$(tput setaf 2;tput bold)
BRIGHT_YELLOW=$(tput setaf 3;tput bold)
BRIGHT_CYAN=$(tput setaf 6;tput bold)
BRIGHT=$(tput bold)
NOCOLOR=$(tput sgr0)

FILELIST=("$@")
declare -i EXIT=0

proc_png() {
  local infile="$@"
  local tmpfile="/tmp/${INFILE}-strip"
  local exit_local=0
  if [ ! -f "$infile" ];then
    warn "${infile} DOES NOT EXIST."
    return 1
  fi
  pngcrush -rem alla -rem text "${infile}" "${tmpfile}"
  exit_local+=$?
  srm -ll "${infile}" &> /dev/null
  cp "$tmpfile" "$infile"
  exit_local+=$?
  srm -ll "${tmpfile}" &> /dev/null
  return $exit_local
}

# $1 is the exit status, and $2 is the error message, be sure to "quote" $2 when
# using it.
help_and_exit() {
    echo "${BRIGHT}pngstrip.sh:${NOCOLOR}" 1>&2
    cat 1>&2 << EOF
This Script strips metadata from pngfiles using the pngcrush binary in batch

	Usage:
	$ pngstrip.sh <filelist>
EOF
exit 1
}

message() {
    echo "${BRIGHT}pngstrip.sh:${NOCOLOR} $@"
}
warn() {
    message "${BRIGHT_YELLOW}WARN:${NOCOLOR} $@" 1>&2
}

exit_with_error() {
   message "${BRIGHT_RED}ERROR:${NOCOLOR} $2" 1>&2
   exit $1
}

#check filelist
[ -z $FILELIST ] && help_and_exit
[ "$FILELIST" == "--help" ] && help_and_exit

#Loop to use pngstrip.sh on every file in order.
for FILE in ${FILELIST[@]};do
  proc_png "$FILE"
  EXIT+=$?
done

[ $EXIT -ne 0 ] && exit_with_error $EXIT "Script complete, $EXIT files failed!"

exit 0

