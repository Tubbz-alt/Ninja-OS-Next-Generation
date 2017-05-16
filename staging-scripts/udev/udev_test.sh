#!/bin/bash

ACTION="$1"
P="$2"
BUSNUM="$3"
DEVNUM="$4"

print_stuff() {
  echo "ACTION: $ACTION"
  echo "P: $P"
  echo "BUS NUMBER: $BUSNUM"
  echo "DEV NUMBER: $DEVNUM"
}

print_stuff >> /var/log/device.log
print_stuff > /var/log/last_device.log
print_stuff
