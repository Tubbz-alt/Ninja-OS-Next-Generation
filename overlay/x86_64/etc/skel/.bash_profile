#
# ~/.bash_profile
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#  our .bash_profile handles the kernel command line nox and xconfigure options,
#  and starts X on virtual terminal 2
[[ -f ~/.bashrc ]] && . ~/.bashrc

## Alternative method to start X
if [[ $(cat /proc/cmdline) == *xconfigure* ]];then
    sudo Xorg -configure
    sudo mv -f /root/xorg.conf.new /etc/X11/xorg.conf
fi

if [[ ! $DISPLAY && $(tty) = /dev/tty1 &&  $(cat /proc/cmdline) != *nox* ]]; then
     # with rootless x, if x is not started from virtual terminal it is running
     # it, it will fail with permissions issues
     exec startx

     #. /usr/share/auto_dpi.sh
     #exec startx /usr/bin/startxfce4 -nolisten tcp -br +bs -dpi $dpi vt$XDG_VTNR

fi

