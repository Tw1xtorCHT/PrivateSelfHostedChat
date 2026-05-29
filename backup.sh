#!/bin/bash

BACKUP_DIR="/root/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/chat_backup_$TIMESTAMP.tar.gz"

mkdir -p $BACKUP_DIR

echo "Создаём бэкап..."

tar -czf $BACKUP_FILE \
  /root/nginx_secure/ \
  /root/auth_server.js \
  /root/rotate_chat_access.sh \
  /root/auto_clear.sh \
  /root/tg_bot.py \
  /root/custom_style.css \
  /root/chat_credentials.txt \
  /root/turn_credentials.txt \
  /root/node_modules/ \
  /root/calls/ \
  /root/caddy_data/ \
  2>/dev/null

echo "Бэкап создан: $BACKUP_FILE"
echo "Размер: $(du -sh $BACKUP_FILE | cut -f1)"

# Оставляем только 5 последних бэкапов
ls -t $BACKUP_DIR/chat_backup_*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null

echo "Готово!"
