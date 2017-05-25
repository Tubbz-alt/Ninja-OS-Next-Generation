#!/bin/bash
#
#  Written for Ninja OS by the development team.
#  licensed under the GPLv3 http://www.gnu.org/licenses/gpl-3.0.html
#
#GUI wrapper for MAT(metadata anonmyization toolkit, sends popups via libnotify to the GUI when mat is done.

mat "$@"
exit="$?"

case $exit in
    0)
      notify-send --icon mat "Metadata Anonimization Toolkit" "Finished Removing Metadata"
      ;;
    *)
      notify-send --icon mat "Metadata Anonimization Toolkit" "Metadata Scrub Failed ${exit}"
      ;;
esac

