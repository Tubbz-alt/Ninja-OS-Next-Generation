#!/bin/sh
# /etc/acpi/powerbtn.sh
# Initiates a shutdown when the power putton has been
# pressed.

timeout=0.8
pid_count=$(pidof -x powerbtn.sh | wc -w)

( if [ $pid_count -eq 4 ]; then
        sleep $timeout
        # action here on 3 powerbutton presses
        #/etc/acpi/sleep.sh
        notify-send "Three powerbutton Presses" "ahahaha"
        echo "Three powerbutton Presses ahahaha"
    else
        sleep $timeout
        pid_count_now=$(pidof -x powerbtn.sh | wc -w)
        if [ $pid_count_now -eq 2 ] && [ $pid_count -eq 2 ]; then
            #action here for one power button press
            #poweroff
            notify-send "One powerbutton Press" "ahahaha"
            echo "One powerbutton Press ahahaha"
        fi
        exit
    fi
) &
