#!/bin/bash

TG_TOKEN="YOUR_BOT_TOKEN"
TG_CHAT_ID="YOUR_CHAT_ID"

NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
LOGIN="user"

# Обновляем пароль Nginx
MD5_PASS=$(openssl passwd -1 "$NEW_PASS")
echo "${LOGIN}:${MD5_PASS}" > /root/nginx_secure/.htpasswd
echo "${LOGIN}:${NEW_PASS}" > /root/chat_credentials.txt

# Перезапускаем шлюз
docker restart secure_gateway > /dev/null

# Отправляем в Telegram через POST с нормальным текстом
MSG="Login: ${LOGIN}
Password: ${NEW_PASS}
Link: https://YOUR_DOMAIN"

curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d "chat_id=${TG_CHAT_ID}" \
  --data-urlencode "text=${MSG}"
echo ""
