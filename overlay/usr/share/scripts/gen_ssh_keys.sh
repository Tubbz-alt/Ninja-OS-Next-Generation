#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#  This script checks and sets up sshd to run securely. adapted from:
#  https://stribika.github.io/2015/01/04/secure-secure-shell.html

#four finger claw
message() {
  echo "$0: $@"
}
submsg(){
  echo "==> $@"
}
exit_with_error() {
  message "ERROR: $2" 1>&2
  exit $1
}

help_and_exit() {
cat 1>&2 << EOF
gen_ssh_keys.sh:

This script generates ssh daemon keys.

	Usage
	# gen_ssh_keys.sh

	Options:
	--help 		this message

EOF
exit 1
}

gen_keys() {
  local -i exit=0
  cd /etc/ssh
  rm -f ssh_host_*key*
  exit+=$?
  submsg "Generating ed22519 key..."
  ssh-keygen -t ed25519 -f ssh_host_ed25519_key < /dev/null > /dev/null
  exit+=$?
  submsg "Generating 4096 bit RSA key..."
  ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key < /dev/null > /dev/null
  exit+=$?
  return $exit
}

gen_moduli() {
  local -i exit=0
  rm -f /etc/ssh/moduli
  exit+=$?
  ssh-keygen -G /etc/ssh/moduli.all -b 4096
  exit+=$?
  ssh-keygen -T /etc/ssh/moduli.safe -f /etc/ssh/moduli.all
  exit+=$?
  mv -f /etc/ssh/moduli.safe /etc/ssh/moduli
  exit+=$?
  rm -f /etc/ssh/moduli.all
  exit+=$?
  return $exit
}

check_moduli() {
  # This function checks /etc/ssh/moduli for a items with a length field of less
  # than 2000
  # I'd be damned this is probably the ugliest bash I ever wrote
  local -i min_len=2000
  local line
  local -i moduli
  readarray moduli_list < /etc/ssh/moduli || return $?
  for ((i=0;i < ${#moduli_list[@]};i++ ));do
    [[ ${moduli_list[$i]} = \#* ]] && continue
    moduli=$( cut -d " " -f 5 <<< ${moduli_list[$i]} )
    if [ ${moduli} -lt ${min_len} ];then
      echo "short"
      return
    fi
  done
  echo "good"
  return 0
}

main() {
  [[ $1 = *help* ]] && help_and_exit
  MOD_CHECK=""
  message "Generating New SSH Keys..."
  try gen_keys
  message "Checking /etc/ssh/moduli..."
  MOD_CHECK=$(try check_moduli)
  if [ $MOD_CHECK == "short" ];then
    message "/etc/ssh/moduli has small entries, regenerating"
    gen_moduli
  fi
  message "done!"
}

main "$@"
