# This script presents the Self Destruct/Zeroize mode as a poppup windwow in
# XFCE. Its really a terminal. We variablized it, so other scripts can use it,
# such as reboot_nuke.sh

xfce4-terminal --command="$1" --hide-menubar --hide-borders --geometry=48x6
