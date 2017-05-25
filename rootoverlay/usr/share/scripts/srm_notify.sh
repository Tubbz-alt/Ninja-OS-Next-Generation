#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#GUI wrapper for SRM, sends popups via libnotify to the GUI when srm is done.

srm -lr "$@"
exit="$?"

case $exit in
    0)
      notify-send --icon edit-delete "Secure-Delete" "Finished Securely Deleting Files"
      ;;
    *)
      notify-send --icon edit-delete "Secure-Delete" "Security Wipe Failed ${exit}"
      ;;
esac

