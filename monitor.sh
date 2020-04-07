#!/bin/bash

logger -s "monitor process..."

regex="WARN|ERROR"

journalctl -f -n 0 -u startrobot |
while read line
do
    logger -s $line;
    if [[ "$line" =~ $regex ]]; then
#        systemctl restart startrobot;
#        logger -s $line;
        sleep 5
        logger -s "monitor force to restart startrobot";
        sudo systemctl restart startrobot;
    fi
done
