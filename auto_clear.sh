#!/bin/bash

TRACK_FILE="/tmp/chat_last_activity"
touch "$TRACK_FILE"

while true; do
    NEW_LOGS=$(docker logs --since 1m anon_chat 2>&1 | grep -v -E "ping|pong|connect|disconnect|keepalive")

    if [ ! -z "$NEW_LOGS" ]; then
        touch "$TRACK_FILE"
    else
        LAST_ACTIVITY=$(stat -c %Y "$TRACK_FILE")
        CURRENT_TIME=$(date +%s)
        IDLE_TIME=$((CURRENT_TIME - LAST_ACTIVITY))

        if [ "$IDLE_TIME" -ge 3600 ]; then
            docker restart anon_chat > /dev/null
            /root/rotate_chat_access.sh
            touch "$TRACK_FILE"
        fi
    fi

    sleep 60
done
