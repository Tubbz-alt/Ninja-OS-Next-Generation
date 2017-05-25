#!/bin/bash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script calculates screen DPI based on information gathered from xrandr,
# and adjusts the screens accordingly. Each monitor is scaled independantly

BRIGHT=$(tput bold)
BRIGHT_RED=$(tput bold;tput setaf 1)
BRIGHT_YELLOW=$(tput bold;tput setaf 3)
NOCOLOR=$(tput sgr0)

# Bash variables. i is for integer. Big A is Associative Array, and little a 
# indexed arrays.
declare -a MonList
declare -i MonCount
declare -A DPI_Table
declare -i EXIT=0

help_and_exit() {
    echo ${BRIGHT}"auto_dpi.sh:"${NOCOLOR} 1>&2
    cat 1>&2 << EOF
This script calculates screen DPI based on information gathered from xrandr, and
adjusts the screen accordingly. Each monitor is scaled independantly

	Usage:
	auto_dpi.sh

EOF
exit 1
}

#first parameter is the exit message, second is the error code
message(){
    echo "${BRIGHT}auto_dpi.sh${NOCOLOR}: ${@}"
}
exit_with_error() {
    message "${BRIGHT_RED} !ERROR!${NOCOLOR} ${2}" 1>&2
    exit ${1}
}
warn() {
    message "${BRIGHT_YELLOW} Warn:${NOCOLOR} ${1}" 1>&2
}

fill_dpi_table() {
    #This function fills DPI_Table with monitorname:DPI pairs
    shopt -s extglob
    local res; local x_res; local y_res
    local size; local x_size; local y_size
    local xrandr_string
    local dpi
    MonList=( $(xrandr |grep " connected"|cut -d " " -f 1) )
    MonCount=${#MonList[@]}
    for mon in ${MonList[@]};do
        # grep the output of xrandr for info on one monitor.
        xrandr_string=$(xrandr |grep ${mon})
        if [ $? -ne 0 ];then
            EXIT+=1
            warn "Can't get sizing information for ${mon}"
            continue
        fi

        # resolution in pixels
        if [ "$res" == "primary" ];then
            res=$(cut -d " " -f 4 <<< $xrandr_string |cut -d "+" -f 1)
            res=${res##*( )}
          else
            res=$(cut -d " " -f 3 <<< $xrandr_string |cut -d "+" -f 1)
            res=${res##*( )}
        fi
        x_res=$(cut -d "x" -f 1 <<< $res )
        y_res=$(cut -d "x" -f 2 <<< $res )

        # physical size in milimeters
        size=$(cut -d ")" -f2 <<< $xrandr_string )
        size=${size##*( )}
        x_size=$(cut -d "x" -f 1 <<< $size | sed 's/mm //g')
        y_size=$(cut -d "x" -f 2 <<< $size | sed 's/mm//g')
        y_size=${y_size##*( )}
        # millimeters! whats a millimeter? We need to convert this communist
        # horseshit into freedom units:
        x_size=$(bc <<< " scale = 2; $x_size / 25")
        y_size=$(bc <<< " scale = 2; $y_size / 25")

        # fuck thats done, I need a beer. the ${var##*( )} is how bash strips
        # spaces. At this point its safe to say "easier done in a real lang,
        # where standard functionality is not an esoteric command". Nonsense I
        # say. This is Arch Linux, Bash scripting is a sacred artform. I do
        # bash-fu. In python this is simply string.strip(" ")

        # Now we compute DPI. Special thanks to xionyc for being awesome at math
        dpi=$( bc <<< "( (${x_res}/${x_size}) + (${y_res}/${y_size}) ) / 2")
        DPI_Table[$mon]=$dpi
    done
    shopt -u extglob
}

dpi_to_scale(){
    # this function converts a standard DPI to scale we can use.
    # 1 is the default. we also know the default DPI is 96.
    local dpi=$1
    local scale
    local output
    scale=$(bc <<< "scale = 3; ${dpi} / 96")
    output="${scale}x${scale}"
    echo ${output}
}

main() {
    [ "$1" == "--help" ] && help_and_exit
    [ "$1" == "help" ] && help_and_exit
    [ -z ${MonList} ] && exit_with_error 1 "No Monitors Found!"
    local dpi
    local scale
    message "Found ${BRIGHT}${MonCount}${NOCOLOR} monitors. Re-adjusting DPI..."
    fill_dpi_table
    for mon in ${MonList[@]};do
        dpi=${DPI_Table[$mon]}
        scale=$(dpi_to_scale $dpi)
        message "${mon} has DPI of ${dpi} and scale is ${scale}"
        xrandr --output ${mon} --scale ${scale}
        if [ $? -ne 0 ];then
            warn "Cannot set scale for ${mon}"
            exit+=1
        fi
    done
    [ $EXIT -ne 0 ] && exit_with_error $EXIT "Script threw ${EXIT} errors, you might want to investigate"
    exit $EXIT
}

main "${@}"
