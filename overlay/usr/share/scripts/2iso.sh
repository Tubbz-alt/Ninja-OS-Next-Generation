#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#	Converts disk images made with proprietary Windows(tm) tools into
# universal .ISO files that any CD write tool will recognize. automaticly
# detects format based on file name. Supports two formats:
#	.nrg - Nero Burning Rom
#	.ccd - CloneCD

#	Usage:
#	2iso.sh <filenames>

FILELIST=(${@})
declare -i EXIT=0

BRIGHT=$(tput bold)
BRIGHT_RED=$(tput setaf 1;tput bold)
BRIGHT_YELLOW=$(tput setaf 3;tput bold)
NOCOLOR=$(tput sgr0)

nrgiso_proccess() {
    # turn one .nrg into an iso
    local -i exit=0
    local infile="$@"
    # output file is just renamed to .iso, we delete the original later
    local outfile="${infile%.nrg}.iso"
    nrg2iso "${infile}" "${outfile}"
    exit=$?
    if [ ${exit} -ne 0 ];then
        warn "ISO converstion for ${infile} failed!"
        return 1
    fi
    #securely delete the original file
    srm -ll "${infile}"
    return 0
}

ccdiso_proccess() {
    # turn one .ccd into an .iso
    local -i exit=0
    local infile="$@"
    # output file is just renamed to .iso, we delete the original later
    local outfile="${infile%.ccd}.iso"
    ccd2iso "${infile}" "${outfile}"
    exit=$?
    if [ ${exit} -ne 0 ];then
        warn "ISO converstion for ${infile} failed!"
        return 1
    fi
    #securely delete the original file
    srm -ll "${infile}"
    return 0
}

# the famous Ninja OS full four fingered fist.
message() {
    echo "${BRIGHT}2iso.sh${NOCOLOR}: $@"
}
exit_with_error() {
    message "${BRIGHT_RED}!ERROR!${NOCOLOR} ${2}" 1>&2
    exit $1
}
warn() {
    message "${BRIGHT_YELLOW}Warn:${NOCOLOR} ${@}" 1>&2
}
help_and_exit() {
    echo "${BRIGHT}2iso.sh${NOCOLOR}:" 1>&2
    cat 1>&2 << EOF
	Converts disk images made with proprietary Windows(tm) tools into
standard ISO9660 .ISO files . automaticly detects format based on file name.
Supports two formats:
	.nrg - Nero Burning Rom
	.ccd - CloneCD

	Usage:
	2iso.sh <filenames>

EOF
exit 1
}

main() {
    #check for a file list. If not print the help
    [ -z "${FILELIST}" ] && help_and_exit
    [ "${FILELIST}" == "--help" ] && help_and_exit

    for FILE in ${FILELIST[@]};do
        #check if file exists. If file does not exist go back to the top
        if [ ! -f ${FILE} ];then
            warn "$FILE does not exist"
            exit+=1
            continue
        fi
        #check file extension:
        local -i ext_fld=$(grep -o "\." <<< ${FILE} |wc -l)
        ext_fld=$(($exit_fld + 1))
        local ext=$(echo "${FILE}"|cut -d "." -f${ext_fld})
        if [ "${ext}" == "nrg" ];then
            nrgiso_proccess "${FILE}" || EXIT+=1
          elif [ "${ext}" == "ccd" ];then
            ccdiso_proccess "${FILE}" || EXIT+=1
          else
            warn "${FILE} is not an .nrg or .ccd file."
            continue
        fi
    done
    #check exit codes before we exit
    [ $EXIT -ne 0 ] && exit_with_error $EXIT "There were $EXIT errors"
    exit 0
}

main "${@}"
