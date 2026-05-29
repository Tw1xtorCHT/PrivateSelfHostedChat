#!/bin/bash

TG_TOKEN="YOUR_BOT_TOKEN"
TG_CHAT_ID="YOUR_CHAT_ID"

NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
LOGIN="user"

# Обновляем пароль для нового движка
echo "${LOGIN}:${NEW_PASS}" > /root/pschat/credentials.txt

# Перезапускаем чат (сбрасывает токены и сообщения)
docker restart pschat > /dev/null

MSG="Login: ${LOGIN}
Password: ${NEW_PASS}
Link: https://YOUR_DOMAIN"

curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d "chat_id=${TG_CHAT_ID}" \
  --data-urlencode "text=${MSG}"
echo ""
