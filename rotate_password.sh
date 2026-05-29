#!/bin/bash

TG_TOKEN="YOUR_BOT_TOKEN"
TG_CHAT_ID="YOUR_CHAT_ID"

NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
LOGIN="user"

# Обновляем пароль для нового движка
HASH=$(echo -n "${NEW_PASS}" | sha256sum | cut -d" " -f1)
echo "${LOGIN}:${HASH}" > /root/pschat/credentials.txt

# Перезапускаем чат (сбрасывает токены и сообщения)
# Обновляем TURN пароль
NEW_TURN=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
echo "TURN_PASS=$NEW_TURN" > /root/turn_credentials.txt
docker rm -f coturn > /dev/null 2>&1
docker run -d --name coturn --restart unless-stopped   -p 3478:3478/udp -p 3478:3478/tcp   coturn/coturn --realm=turn --user=chat:$NEW_TURN --lt-cred-mech --no-cli > /dev/null 2>&1

docker restart pschat > /dev/null

MSG="Login: ${LOGIN}
Password: ${NEW_PASS}
Link: https://YOUR_DOMAIN"

curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d "chat_id=${TG_CHAT_ID}" \
  --data-urlencode "text=${MSG}"
echo ""
