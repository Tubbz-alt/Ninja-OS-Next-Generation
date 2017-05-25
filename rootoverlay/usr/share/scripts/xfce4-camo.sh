#!/bin/bash
#
#  Written for the NinjaOS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
# This script disguises XFCE as another Operating System. use xfce4-camo.sh <OS-NAME>. Still experimental
source /usr/share/scripts/liveos_lib.sh

camo_win7(){
  # Disguise XFCE as Windows 7 with the classic theme.
  cp /usr/share/camo/win7/whiskermenu-1.rc /home/user/.config/xfce4/panel/
  xfce4-panel -r
  #chown user:users /home/user/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
  xfconf-query -c xsettings -p /Net/ThemeName -s "Xfce-redmondxp"
  xfconf-query -c xsettings -p /Gtk/FontName "Tahoma 10"
  xfconf-query -c xfwm4 -p /general/theme -s "Redmond"
  xfconf-query -c xfwm4 -p /general/title_font -s "Tahoma Bold 9"
}

camo_winxp(){
  # Use the Windows XP themes built into XFCE. Also reload the panel
  cp /usr/share/camo/winxp/whiskermenu-1.rc /home/user/.config/xfce4/panel/
  xfce4-panel -r

  xfconf-query -c xsettings -p /Net/ThemeName -s "Xfce-redmondxp"
  xfconf-query -c xsettings -p /Gtk/FontName "Tahoma 10"
  xfconf-query -c xfwm4 -p /general/theme -s "RedmondXP"
  xfconf-query -c xfwm4 -p /general/title_font -s "Tahoma Bold 9"
}

case ${1} in
  winxp)
    #Work in Proggress. Please note this does not work entirely as expected.
    camo_winxp
    echo "Windows XP Camouflage Work in Progress"
    ;;
  win7)
    camo_win7
    echo "Windows 7 Camoflage Work in Progress"
    ;;
  win10)
    #xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-icon -s "start_icon8"
    echo "Windows 10 Camouflage not implemented yet"
    exit 1
    ;;
  osx)
    echo "Mac OSX Camouflage not implemented yet"
    exit 1
    ;;
  *)
    echo "${SCRIPT_NAME}: We don't have camouflauge for $1, valid options are \"winxp, win7, win10, and osx\""
    exit 1
    ;;
esac

