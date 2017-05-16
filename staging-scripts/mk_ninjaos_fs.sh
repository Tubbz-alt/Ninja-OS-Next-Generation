#!/bin/bash
# format a partition for Ninja OS
mkfs.ext4 -O \^64bit -O \^has_journal ${1} -L "Ninja OS"
