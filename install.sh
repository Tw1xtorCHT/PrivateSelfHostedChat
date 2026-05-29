#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "======================================"
echo "   PrivateSelfHostedChat - Setup      "
echo "======================================"
echo -e "${NC}"
echo -e "${YELLOW}You will need:${NC}"
echo "1. Bot token - @BotFather in Telegram"
echo "2. Your Chat ID - @userinfobot in Telegram"
echo "3. Domain - free at duckdns.org"
echo ""
read -p "Bot token: " TG_TOKEN
read -p "Your Chat ID: " TG_CHAT_ID
read -p "Domain (e.g. mychat.duckdns.org): " DOMAIN
echo ""
echo -e "${YELLOW}Installing...${NC}"

# Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
fi
echo -e "${GREEN}+ Docker${NC}"

# Dependencies
apt-get install -y python3-pip -qq > /dev/null 2>&1
pip3 install python-telegram-bot --break-system-packages -q > /dev/null 2>&1
echo -e "${GREEN}+ Dependencies${NC}"

# Folders
mkdir -p /root/pschat/public /root/nginx_secure /root/caddy_data /root/backups

# Download chat engine
REPO="https://raw.githubusercontent.com/Tw1xtorCHT/PrivateSelfHostedChat/main"
curl -s "$REPO/server.js" -o /root/pschat/server.js
curl -s "$REPO/public/index.html" -o /root/pschat/public/index.html
curl -s "$REPO/public/login.html" -o /root/pschat/public/login.html
echo -e "${GREEN}+ Chat engine downloaded${NC}"

# Install node dependencies
docker run --rm -v /root/pschat:/app -w /app node:18-alpine sh -c "npm init -y && npm install express socket.io" > /dev/null 2>&1
echo -e "${GREEN}+ Node modules${NC}"

# Generate password
NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
echo "user:${NEW_PASS}" > /root/pschat/credentials.txt

# Generate TURN password
TURN_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
echo "TURN_PASS=$TURN_PASS" > /root/turn_credentials.txt

# Docker network
docker network create secure_net 2>/dev/null

# Chat
docker run -d --name pschat --network secure_net --restart unless-stopped \
  -v /root/pschat:/app -w /app node:18-alpine node server.js 80 > /dev/null 2>&1
sleep 2
echo -e "${GREEN}+ Chat server${NC}"

# Coturn
docker run -d --name coturn --restart unless-stopped \
  -p 3478:3478/udp -p 3478:3478/tcp \
  coturn/coturn --realm=$DOMAIN --user=chat:$TURN_PASS --lt-cred-mech --no-cli > /dev/null 2>&1
echo -e "${GREEN}+ TURN server${NC}"

# Nginx
cat > /root/nginx_secure/nginx.conf << 'NGEOF'
events { worker_connections 1024; }
http {
    server {
        listen 80;
        location / {
            proxy_pass http://pschat:80/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header Cookie $http_cookie;
            proxy_read_timeout 3600s;
            client_max_body_size 50M;
        }
    }
}
NGEOF
docker run -d --name secure_gateway --network secure_net --restart unless-stopped \
  -p 8080:80 \
  -v /root/nginx_secure/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:alpine > /dev/null 2>&1
echo -e "${GREEN}+ Nginx${NC}"

# Caddy HTTPS
docker run -d --name caddy --network secure_net --restart unless-stopped \
  -p 80:80 -p 443:443 -v /root/caddy_data:/data \
  caddy:2-alpine caddy reverse-proxy --from $DOMAIN --to secure_gateway:80 > /dev/null 2>&1
echo -e "${GREEN}+ Caddy HTTPS${NC}"

# Rotate password script
cat > /root/rotate_password.sh << ROTEOF
#!/bin/bash
TG_TOKEN="${TG_TOKEN}"
TG_CHAT_ID="${TG_CHAT_ID}"
NEW_PASS=\$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
LOGIN="user"
echo "\${LOGIN}:\${NEW_PASS}" > /root/pschat/credentials.txt
docker restart pschat > /dev/null
MSG="Login: \${LOGIN}
Password: \${NEW_PASS}
Link: https://${DOMAIN}"
curl -s -X POST "https://api.telegram.org/bot\${TG_TOKEN}/sendMessage" \
  -d "chat_id=\${TG_CHAT_ID}" --data-urlencode "text=\${MSG}"
echo ""
ROTEOF
chmod +x /root/rotate_password.sh

# Auto clear
cat > /root/auto_clear.sh << 'CLREOF'
#!/bin/bash
TRACK_FILE="/tmp/chat_last_activity"
touch "$TRACK_FILE"
while true; do
    NEW_LOGS=$(docker logs --since 1m pschat 2>&1 | grep -v -E "ping|pong|running")
    if [ ! -z "$NEW_LOGS" ]; then touch "$TRACK_FILE"
    else
        LAST_ACTIVITY=$(stat -c %Y "$TRACK_FILE")
        IDLE_TIME=$(($(date +%s) - LAST_ACTIVITY))
        if [ "$IDLE_TIME" -ge 3600 ]; then
            docker restart pschat > /dev/null
            /root/rotate_password.sh
            touch "$TRACK_FILE"
        fi
    fi
    sleep 60
done
CLREOF
chmod +x /root/auto_clear.sh

# Telegram bot
cat > /root/tg_bot.py << BOTEOF
import subprocess
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
TG_TOKEN = "${TG_TOKEN}"
TG_CHAT_ID = ${TG_CHAT_ID}
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != TG_CHAT_ID: return
    keyboard = [[InlineKeyboardButton("Reset chat", callback_data="reset")]]
    await update.message.reply_text("Chat management:", reply_markup=InlineKeyboardMarkup(keyboard))
async def button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    if query.from_user.id != TG_CHAT_ID: return
    await query.answer()
    await query.edit_message_text("Resetting...")
    subprocess.run(["docker", "restart", "pschat"])
    subprocess.run(["/root/rotate_password.sh"])
    await query.edit_message_text("Done! New password sent.")
app = Application.builder().token(TG_TOKEN).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CallbackQueryHandler(button))
app.run_polling()
BOTEOF

# Backup script
cat > /root/backup.sh << 'BKEOF'
#!/bin/bash
DIR="/root/backups"
mkdir -p $DIR
tar -czf "$DIR/chat_$(date +%Y%m%d_%H%M%S).tar.gz" /root/pschat/ /root/nginx_secure/ /root/rotate_password.sh /root/auto_clear.sh /root/tg_bot.py /root/turn_credentials.txt 2>/dev/null
echo "Backup saved"
ls -t $DIR/chat_*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null
BKEOF
chmod +x /root/backup.sh

# Cron
(crontab -l 2>/dev/null; echo "@reboot nohup python3 /root/tg_bot.py > /var/log/tg_bot.log 2>&1 &") | crontab -
(crontab -l 2>/dev/null; echo "@reboot nohup /root/auto_clear.sh > /var/log/chat_auto_clear.log 2>&1 &") | crontab -
(crontab -l 2>/dev/null; echo "0 3 * * * /root/backup.sh > /var/log/backup.log 2>&1") | crontab -

# Start services
nohup /root/auto_clear.sh > /var/log/chat_auto_clear.log 2>&1 &
sleep 2
curl -s "https://api.telegram.org/bot${TG_TOKEN}/deleteWebhook?drop_pending_updates=true" > /dev/null
nohup python3 /root/tg_bot.py > /var/log/tg_bot.log 2>&1 &
sleep 3
/root/rotate_password.sh > /dev/null

echo ""
echo -e "${GREEN}"
echo "======================================"
echo "         Setup complete!              "
echo "======================================"
echo -e "${NC}"
echo -e "Chat: ${GREEN}https://${DOMAIN}${NC}"
echo -e "Bot: send ${GREEN}/start${NC} to your bot"
echo -e "Password sent to Telegram"
echo ""
echo -e "${YELLOW}Wait 30-60 sec for SSL certificate${NC}"
