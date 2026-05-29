#!/bin/bash

BACKUP_DIR="/root/backups"

# Показываем список бэкапов
echo "Доступные бэкапы:"
ls -t $BACKUP_DIR/chat_backup_*.tar.gz 2>/dev/null | nl

echo ""
read -p "Введите номер бэкапа для восстановления: " NUM

BACKUP_FILE=$(ls -t $BACKUP_DIR/chat_backup_*.tar.gz 2>/dev/null | sed -n "${NUM}p")

if [ -z "$BACKUP_FILE" ]; then
    echo "Бэкап не найден"
    exit 1
fi

echo "Восстанавливаем из: $BACKUP_FILE"

# Распаковываем
tar -xzf $BACKUP_FILE -C / 2>/dev/null

# Перезапускаем всё
echo "Перезапускаем контейнеры..."

docker rm -f anon_chat secure_gateway caddy auth_server signal_server 2>/dev/null

docker network create secure_net 2>/dev/null

docker run -d --name anon_chat --network secure_net --restart unless-stopped \
  -e CHAT_MAX_FILE_SIZE=52428800 m1k1o/chat:latest

sleep 2
docker cp /root/custom_style.css anon_chat:/usr/src/app/html/static/styles/style.css
docker exec anon_chat sh -c "echo '' > /usr/src/app/html/static/styles/dark.css"

docker run -d --name secure_gateway --network secure_net --restart unless-stopped \
  -p 8080:80 \
  -v /root/nginx_secure/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v /root/nginx_secure/.htpasswd:/etc/nginx/.htpasswd:ro \
  nginx:alpine

docker run -d --name auth_server --network secure_net --restart unless-stopped \
  -v /root/auth_server.js:/app/auth_server.js \
  -v /root/chat_credentials.txt:/app/chat_credentials.txt \
  -v /root/node_modules:/app/node_modules \
  -w /app node:18-alpine node auth_server.js

docker run -d --name signal_server --network secure_net --restart unless-stopped \
  -v /root/calls:/app -w /app node:18-alpine node signal.js

docker run -d --name caddy --network secure_net --restart unless-stopped \
  -p 80:80 -p 443:443 \
  -v /root/caddy_data:/data \
  caddy:2-alpine caddy reverse-proxy \
  --from $(grep -o 'YOUR_DOMAIN_PREFIX[^"]*' /root/rotate_chat_access.sh | head -1) \
  --to secure_gateway:80

sleep 3

pkill -f tg_bot.py 2>/dev/null
pkill -f auto_clear.sh 2>/dev/null
sleep 2
nohup python3 /root/tg_bot.py > /var/log/tg_bot.log 2>&1 &
nohup /root/auto_clear.sh > /var/log/chat_auto_clear.log 2>&1 &

/root/rotate_chat_access.sh > /dev/null

echo ""
echo "✅ Восстановление завершено!"
echo "Новый пароль отправлен в Telegram"
