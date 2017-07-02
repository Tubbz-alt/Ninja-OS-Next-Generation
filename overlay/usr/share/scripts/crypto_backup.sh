#!/bin/bash
#
#  Written for the Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# Script to back up GPG and OTR keys to a specified location. use as
# crypto_backup.sh (--restore) <backup location>
source /usr/share/scripts/liveos_lib.sh

declare -i COPY_FAIL=0
declare -i COPY_OK=0
declare RESTORE=false
declare CHECK_ONLY=false
declare TMP_DIR="/tmp"

help_and_exit() {
    echo  1>&2 "${BRIGHT}crypto_backup.sh:${NOCOLOR}"
cat 1>&2 << EOF
This script backs up(or restores) GPG and OTR keys in the user directory to an 
archive file. you need to specify a taget name.

crypt_backup.tar.gz is automaticly appended to target name durring backup.

	usage:
	crypto_backup.sh [--options] <target>.crypt_backup.tar.gz

	Options:

        -c, --check-only - only check archive backup file, do no operations

	-r, --restore - Restore previously backed up crypto keys from
		    	archive file

EOF
exit 1
}

message() {
  echo "${BRIGHT}crypto_backup.sh${NOCOLOR}: ${@}"
}
submsg(){
    echo "		${@}"
}
warn(){
  message "${BRIGHTYELLOW}WARN!:${NO COLOR} ${@}" 1>&2
}
exit_with_error(){
  message "${BRIGHTRED}ERROR:${NOCOLOR} ${2}" 1>&2
  exit ${1}
}

#check if a a copy operation fails
copy_check() {
  local -i exit_status=0
  local src="$1"
  local dest="$2"
  [ ! -z $3 ] && local flags="${3}"
  if [ -f "${src}" ];then
    cp -ra "${src}" "${dst}"
    exit_status=${?}
   else
    warn "No such file ${src}"
  fi
  if [ $exit_status -eq 0 ];then
    submsg "Copied ${src} to ${dest}"
    COPY_OK+=1
   else
    warn "Could not copy ${src}!"
    COPY_FAIL+=1
  fi
  return $exit_status
}

package_check(){
  # check to see if file is valid backup file
  local target="${1}"
  tar zxf "${target}" meta_file -C "${TMP_DIR}" || \
    exit_with_error 1 "Cannot extract data from ${target}, is it a valid archive?"
  source "${TMP_DIR}/meta_file" || \
    exit_with_error 1 "Cannot read metadata from ${target} file, is this a valid crypto backup?"
  [ ${type} == "crypto-backup" ] || \
    exit_with_error 1 "${target} is not a crypo back up file. exiting..."
}

target_check(){
  # check if we can write to target
  local target="${1}"
  local tmp="${TMP_DIR}/${target}"
  local archive="${target}.crypt_backup.tar.gz"
  touch "${tmp}" || exit_with_error 1 "Cannot write to temp directory, backup failed!"
  touch "${archive}" || exit_with_error 1 "cannot write to ${archive}, backup failed!"
  # clean up tests
  rm -r "${target}"
  rm -r "${archive}"
}

crypto_restore() {
  #Do the inverse, and copy keys from a backup to the running system
  message "Restoring GPG and OTR Keys to ${HOME}"
  exit_with_error 1 "NOT FINISHED"
}
crypto_backup() {
  local target=$(basename "${1}")
  local tmp="${TMP_DIR}/${target}"
  local archive="${TARGET}.crypt_backup.tar.gz"
  #backup crypto keys 
  message "Backing up GPG and OTR Keys to ${archive}"
  #double checking files don't e
  mkdir -p "${tmp}"
  copy_check "${HOME}/.gnupg/" "${tmp}/.gnupg/"
  copy_check "${HOME}/.purple/otr.fingerprints" "${tmp}/.purple/otr.fingerprints"
  copy_check "${HOME}/.purple/otr.private_key" "${tmp}/.purple/otr.private_key"
  copy_check "${HOME}/.config/hexchat/otr/" "${tmp}/.config/hexchat/otr/"
  tar zc "${archive}" "${tmp}" || exit_with_error 1 "Creation of backup ${archive} FAILED!"
cat > "${tmp}/meta_file" <<- EOF
# Live OS crypto backup archive. This is the metadata file
# Backup made by $OSNAME $OSVERSION $OSARCH using a script named:
# $SCRIPT_NAME
type="crypto-backup"
type_ver=1
copy_ok=${COPY_OK}
EOF
  rm -rf ${tmp}
  message "Crypto Keys Backed Up To ${archive}, Backed up ${COPY_OK} files, ${COPY_FAILURES} failures."
  exit ${COPY_FAIL}
}
##switches
switch_checker() {
  while [ ! -z "$1" ];do
   case "$1" in
    --help|-?)
     help_and_exit 
     ;;
    --restore|-r)
     RESTORE=true
     ;;
    --check-only|-c)
     CHECK_ONLY=true
     ;;
    *)
     # This is not a switch, we make the new command line without switches.
     # counting can be done with ${#}
     PARMS+="${1}"
     ;;
   esac
   shift
  done
}
main(){
  TARGET="${1}"
  [ -z ${TARGET} ] && help_and_exit
   if [ ${RESTORE} == "true" ];then
    #if we are restoring, check if package is valid, then restore
    package_check "${TARGET}"
    [ ${CHECK_ONLY} == "true" ] && exit ${?}
    crypto_restore "${TARGET}"
   else
    #if backing up, check to make sure we can write the package first
    target_check "${TARGET}"
    crypto_backup "${TARGET}"
  fi
}
switch_checker "${@}"
set ${PARAMS}
main ${PARAMS}
