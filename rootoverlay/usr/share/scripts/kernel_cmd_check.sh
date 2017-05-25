#!/bin/bash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script proccesses Ninja OS specific items entered on the kernel command
# line. It is called by systemd at startup. options "nox" and "xconfigure" are
# in ~/.bash_profile
CMDLINE="$(cat /proc/cmdline)"
USERHOME="/home/user"
USERNAME="user"
USERGROUP="users"

self_destruct() {
    rm "${USERHOME}/.bash_profile"
    cp /usr/share/scripts/liveos_sd.sh "${USERHOME}/.bash_profile"
}

auto_dpi() {
    cp /usr/share/scripts/auto_dpi.desktop "${USERHOME}/.config/autostart/"
    chown ${USERNAME}:${USERGROUP} "${USERHOME}/.config/autostart/auto_dpi.desktop"
}

priv_mode() {
    ## activate privacy mode
    # scramble ethernet MACs and the system hostname
    /usr/share/scripts/mh_scramble.py --use-vendor-bytes

    # Add "rescramble" option to the desktop
    cp /usr/share/scripts/notify-privmode.desktop "${USERHOME}/.config/autostart/"
    cp /usr/share/scripts/rescramble.desktop "${USERHOME}/Desktop/"
    cp /usr/share/scripts/rescramble.desktop "/usr/share/applications/"
    chown ${USERNAME}:${USERGROUP} "${USERHOME}/.config/autostart/notify-privmode.desktop"
    chown ${USERNAME}:${USERGROUP} "${USERHOME}/Desktop/rescramble.desktop"
    chmod +x "${USERHOME}/Desktop/rescramble.desktop"

    #cp /usr/share/scripts/i2p_daemon_controller.desktop "${USERHOME}/Desktop/"
    #chown ${USERNAME}:${USERGROUP} "${USERHOME}/Desktop/i2p_daemon_controller.desktop"
}

start_sshd() {
    #generate ssh keys and start sshd.
    /usr/share/scripts/gen_ssh_keys.sh
    systemctl start sshd
}

cmdline_check(){
    # check for options in /proc/cmdline
    set $CMDLINE
    while [ ! -z "$1" ];do
        case "$1" in
          selfdestruct|zeroize|zzz)
            self_destruct
            ;;
          privmodetrue)
            priv_mode
            ;;
          autodpi)
            auto_dpi
            ;;
          sshd)
            ( start_sshd ) &
            ;;
          camo-*)
            CAMO_PATTERN=$(cut -f 2 -d "-" <<< $1 )
            /usr/share/scripts/xfce4-camo.sh $CAMO_PATTERN
            ;;
          *)
            #catch all for words we don't care about
            true
            ;;
        esac
        shift
    done   
}
## Lets check if zeroize was selected at start up. zeroize is now a
# synonym for self-destruct
[[ ${CMDLINE} == *selfdestruct* ]] && self_destruct
[[ ${CMDLINE} == *zeroize* ]] && self_destruct
[[ ${CMDLINE} == *zzz* ]] && self_destruct

# privacy mode
[[ ${CMDLINE} == *privmodetrue* ]] && priv_mode

# Automatic DPI setting
[[ ${CMDLINE} == *autodpi* ]] && auto_dpi

# generate sshd keys
[[ ${CMDLINE} == *sshd* ]] && start_sshd

# Check for camouflage arguments. elif statements, only one can be picked.
if [[ ${CMDLINE} == *camo-winxp* ]];then
    /usr/share/scripts/xfce4-camo.sh winxp

  elif [[ ${CMDLINE} == *camo-win7* ]];then
    /usr/share/scripts/xfce4-camo.sh win7

  elif [[ ${CMDLINE} == *camo-win8* ]];then
    /usr/share/scripts/xfce4-camo.sh win8

  elif [[ ${CMDLINE} == *camo-osx* ]];then
    /usr/share/scripts/xfce4-camo.sh osx
fi

