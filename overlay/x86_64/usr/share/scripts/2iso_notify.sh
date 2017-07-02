#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#GUI wrapper for 2iso.sh, sends popups via libnotify when done.
declare -i exit=0

/usr/share/scripts/2iso.sh "$@"
exit="$?"

case $exit in
    0)
      notify-send --icon media-optical "ISO Conversion" "Successfully Converted files to .iso"
      ;;
    *)
      notify-send --icon media-optical "ISO Conversion" "Conversion Failed ${exit}"
      ;;
esac

