#!/bin/bash
DIR="/root/backups"
echo "Available backups:"
ls -t $DIR/chat_*.tar.gz 2>/dev/null | nl
read -p "Enter number: " NUM
FILE=$(ls -t $DIR/chat_*.tar.gz 2>/dev/null | sed -n "${NUM}p")
if [ -z "$FILE" ]; then echo "Not found"; exit 1; fi
tar -xzf $FILE -C / 2>/dev/null
docker restart pschat secure_gateway caddy
pkill -f tg_bot.py; pkill -f auto_clear.sh
sleep 3
nohup python3 /root/tg_bot.py > /var/log/tg_bot.log 2>&1 &
nohup /root/auto_clear.sh > /var/log/chat_auto_clear.log 2>&1 &
/root/rotate_password.sh > /dev/null
echo "Restored!"
