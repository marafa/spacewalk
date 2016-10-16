#!/bin/sh

echo "WARNING! This script is destructive!"

echo "Press Ctrl-C within the next 15 seconds to abort erasing everything!"
sleep 15
master_channel=`spacewalk-remove-channel -l|head -1`

echo "Press Ctrl-C within the next 5 seconds to abort deleting $master_channel"
spacewalk-remove-channel -a $master_channel --unsubscribe --force
