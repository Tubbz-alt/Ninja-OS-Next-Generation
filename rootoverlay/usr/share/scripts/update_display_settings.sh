#!/bin/bash
#This snippet runs the xfce4 display tool, and then uses multi-mon.sh to reposition the monitors when done.

/usr/bin/xfce4-display-settings

/usr/share/scripts/multi_mon.sh

#experimental, automaticly set DPI
#/usr/share/scripts/auto_dpi.sh
