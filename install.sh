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

echo -e "${YELLOW}You will need 3 things:${NC}"
echo "1. Telegram bot token - get from @BotFather"
echo "2. Your Chat ID - get from @userinfobot"
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
    echo -e "${GREEN}+ Docker${NC}"
else
    echo -e "${GREEN}+ Docker already installed${NC}"
fi

# Dependencies
echo "Installing dependencies..."
apt-get install -y python3-pip -qq > /dev/null 2>&1
pip3 install python-telegram-bot --break-system-packages -q > /dev/null 2>&1
echo -e "${GREEN}+ Dependencies${NC}"

# Folders
mkdir -p /root/nginx_secure /root/caddy_data /root/calls /root/backups

# Generate first password
NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
MD5_PASS=$(openssl passwd -1 "$NEW_PASS")
echo "user:${MD5_PASS}" > /root/nginx_secure/.htpasswd
echo "user:${NEW_PASS}" > /root/chat_credentials.txt

# Generate TURN password
TURN_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
echo "TURN_PASS=$TURN_PASS" > /root/turn_credentials.txt

# Docker network
docker network create secure_net 2>/dev/null

# ---- CHAT ----
echo "Starting chat..."
docker run -d --name anon_chat --network secure_net --restart unless-stopped \
  -e CHAT_MAX_FILE_SIZE=52428800 m1k1o/chat:latest > /dev/null 2>&1
sleep 3
echo -e "${GREEN}+ Chat${NC}"

# ---- CUSTOM STYLE ----
cat > /tmp/style.css << 'CSSEOF'
html, body{ height: 100%; }
body{ font-family: Monospace; background: #fff; overflow: hidden; margin: 0; }
a { color: black; text-decoration: underline; }
#offline{ padding: 20px 10px; font-size: 14px; }
#offline .big{ font-size: 32px; line-height: 32px; }
.chat{ padding: 0 10px; overflow: hidden; height: 100%; display: flex; flex-direction: column; max-width: 950px; margin-right: auto; margin-left: auto; position: relative; }
#msgs { flex-grow: 1; overflow-y: auto; display: flex; flex-shrink: 0; flex-direction: column-reverse; }
.msgs { margin: 0; padding: 0; padding-bottom: 5px; }
.msgs li { list-style: none; margin: 0; overflow: hidden; margin-bottom: 5px; display: flex; }
.message-from-self { padding-right: 6px; justify-content: flex-end; text-align: right; display: flex; }
#typing li { display: inline-block; margin-right: 5px; }
.msgs li .body { display: block; overflow: hidden; word-wrap: break-word; }
.msgs li .message { position: relative; padding: 6px 12px; border-radius: 1.3em; text-align: left; background: #e5e4e4; display: inline-block; max-width: 450px; color: #000; }
.msgs li .prefix{ margin-top: 10px; }
.msgs li .prefix, .msgs li .suffix { padding-left: 12px; display: block; color: rgba(0,0,0,.40); font-size: 12px; clear: both; }
@media only screen and (max-width: 600px){ .msgs li .message { max-width: 75vw; } }
.msgs li .writing .one, .msgs li .writing .two, .msgs li .writing .three { opacity: .2; animation: dot 2s infinite; }
.msgs li .writing .one { animation-delay: 0.0s; }
.msgs li .writing .two { animation-delay: 0.5s; }
.msgs li .writing .three { animation-delay: 1s; padding-right: 2px; }
@keyframes dot { 0% { opacity: .2; } 25% { opacity: 1; } 100% { opacity: .2; } }
.msgs li.in .message { float: left; margin-left: 20px; background: #e5e4e4; }
.msgs li.in .message:before, .msgs li.in .message:after { right: 100%; top: 18px; border: solid transparent; content: " "; height: 0; width: 0; position: absolute; pointer-events: none; }
.msgs li.in .message:after { border-right-color: #fff; border-width: 8px; margin-top: -8px; }
.msgs li.in .message:before { border-right-color: #bbb; border-width: 9px; margin-top: -9px; }
.msgs li.in .prefix, .msgs li.in .suffix { padding-left: 30px; text-align: left; }
.msgs li.out .message { float: right; margin-right: 20px; background: #000; color: #fff; }
.msgs li.out .message:before, .msgs li.out .message:after { left: 100%; top: 18px; border: solid transparent; content: " "; height: 0; width: 0; position: absolute; pointer-events: none; }
.msgs li.out .message:after { border-left-color: #000; border-width: 8px; margin-top: -8px; }
.msgs li.out .message:before { border-left-color: #333; border-width: 9px; margin-top: -9px; }
.msgs li.out .prefix, .msgs li.out .suffix { padding-right: 30px; text-align: right; }
.msgs li.split { text-align: center; position: relative; padding: 20px 0; }
.msgs li.split:before { content: ""; display: block; border-top: solid 1px #bbb; width: 100%; height: 1px; position: absolute; top: 50%; z-index: 1; }
.msgs li.split .text { display: inline-block; background: #e5e5e5; padding: 0 20px; position: relative; z-index: 5; color: #666; }
.chat-box { flex-grow: 1; display: flex; flex-direction: column; overflow-y: scroll; position: relative; }
.chat-form { background: #fff; padding: 10px; position: relative; }
.chat-form .form-control { display: inline-block; width: 100%; border: 1px solid #bbb; border-radius: 0; padding: 10px; margin: 0; color: #333; background-color: #fff; font-size: 14px; box-shadow: none; height: 39px; box-sizing: border-box; }
.chat-form .form-control:focus { outline: 0; box-shadow: none; }
#send{ background: #000; color: #fff; text-transform: uppercase; padding: 5px; margin: 0 10px 0 0; border: 1px solid #000; border-radius: 0; }
#emic_btn { float: right; margin: 0; position: absolute; right: 10px; bottom: 40px; margin-top: 35px; z-index: 100; background: none; border: none; padding: 8px; }
#users, #users li{ margin: 0; padding: 0; display: inline-block; }
#users li:after { content: ""; padding: 0 5px; }
#users li:last-child:after { content: ""; }
CSSEOF
docker cp /tmp/style.css anon_chat:/usr/src/app/html/static/styles/style.css
docker exec anon_chat sh -c "echo '' > /usr/src/app/html/static/styles/dark.css"

# ---- INDEX.HTML WITH CALL BUTTON ----
cat > /tmp/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
        <meta charset="utf-8">
        <title>Chat</title>
        <meta content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0" name="viewport" />
        <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
        <link href="static/styles/style.css" rel="stylesheet" type="text/css">
</head>
<body>
        <div class="chat">
                <div id="chat-box" class="chat-box">
                        <div id="offline"><span class="big">Server is offline.</span><br />Sorry for that.</div>
                        <ul id="msgs" class="msgs"></ul>
                        <ul id="typing" class="msgs"></ul>
                </div>
                <div class="chat-form">
                        <ul id="emic" style="display:none;"></ul>
                        <button id="emic_btn">
                                <img src="static/emic/white-smiling-face.png" width="20px" height="20px" title="White Smiling Face">
                        </button>
                        <textarea id="form_input" class="form-control" data-user-id="2" placeholder="Type something ..." rows="1"></textarea>
                        <button id="send">Send</button>
                        <button id="call-btn" style="background:#000;color:#fff;border:none;padding:5px 10px;cursor:pointer;font-family:Monospace;font-size:14px;margin:0 5px" onclick="window.open('/call.html','_blank','width=500,height=350')">&#128222;</button>
                        <ul id="users"></ul>
                </div>
        </div>
        <script type="text/javascript" src="socket.io/socket.io.js"></script>
        <script type="text/javascript" src="static/scripts/emic.js"></script>
        <script type="text/javascript" src="static/scripts/chat.js"></script>
        <script type="text/javascript">
                const socket = io(location.protocol + '//' + location.host, { path: location.pathname.replace(/\/$/, '') + '/socket.io/' })
                Emic.init();
                Chat.init(socket);
        </script>
</body>
</html>
HTMLEOF
docker cp /tmp/index.html anon_chat:/usr/src/app/html/index.html

# ---- CALL PAGE ----
cat > /tmp/call.html << CALLEOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Call</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Monospace; background: #fff; margin: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; }
        h2 { margin-bottom: 10px; }
        button { background: #000; color: #fff; border: none; padding: 10px 20px; cursor: pointer; font-family: Monospace; font-size: 14px; margin: 5px; }
        button.red { background: #cc0000; }
        #status { margin: 15px; color: #666; font-size: 13px; text-align: center; }
        #timer { font-size: 28px; margin: 5px; font-weight: bold; }
        .levels { display: flex; gap: 40px; margin: 15px 0; }
        .level-box { text-align: center; }
        .level-label { font-size: 12px; color: #666; margin-bottom: 5px; }
        .level-bar-bg { width: 30px; height: 150px; background: #eee; border: 1px solid #000; position: relative; }
        .level-bar { position: absolute; bottom: 0; width: 100%; background: #000; transition: height 0.05s; }
    </style>
</head>
<body>
    <h2>Voice Call</h2>
    <div class="levels">
        <div class="level-box"><div class="level-label">You</div><div class="level-bar-bg"><div class="level-bar" id="localLevel"></div></div></div>
        <div class="level-box"><div class="level-label">Peer</div><div class="level-bar-bg"><div class="level-bar" id="remoteLevel"></div></div></div>
    </div>
    <div id="timer"></div>
    <div id="status">Press Call to start</div>
    <div>
        <button onclick="startCall()">Call</button>
        <button class="red" onclick="endCall()">End</button>
        <button onclick="toggleMute()" id="muteBtn">Mute</button>
    </div>
    <audio id="remoteAudio" autoplay></audio>
    <script src="/signal/socket.io/socket.io.js"></script>
    <script>
        var ROOM = "call_room_1";
        var iceConfig = { iceServers: [
            { urls: "stun:stun.l.google.com:19302" },
            { urls: "turn:${DOMAIN}:3478", username: "chat", credential: "${TURN_PASS}" }
        ]};
        var socket = io({ path: "/signal/socket.io/" });
        var pc = null, localStream = null, isMuted = false, timerInterval = null, seconds = 0;
        var localAnalyser = null, remoteAnalyser = null, audioCtx = null, levelRAF = null;
        function startLevelMeters() {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            if (localStream) { localAnalyser = audioCtx.createAnalyser(); localAnalyser.fftSize = 256; audioCtx.createMediaStreamSource(localStream).connect(localAnalyser); }
            updateLevels();
        }
        function connectRemoteAnalyser(stream) {
            if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            remoteAnalyser = audioCtx.createAnalyser(); remoteAnalyser.fftSize = 256;
            audioCtx.createMediaStreamSource(stream).connect(remoteAnalyser);
        }
        function updateLevels() {
            var localBar = document.getElementById("localLevel"), remoteBar = document.getElementById("remoteLevel");
            if (localAnalyser) { var d = new Uint8Array(localAnalyser.frequencyBinCount); localAnalyser.getByteFrequencyData(d); var a = d.reduce(function(x,y){return x+y},0)/d.length; localBar.style.height = Math.min(100,(a/128)*100)+"%"; } else { localBar.style.height = "0%"; }
            if (remoteAnalyser) { var d = new Uint8Array(remoteAnalyser.frequencyBinCount); remoteAnalyser.getByteFrequencyData(d); var a = d.reduce(function(x,y){return x+y},0)/d.length; remoteBar.style.height = Math.min(100,(a/128)*100)+"%"; } else { remoteBar.style.height = "0%"; }
            levelRAF = requestAnimationFrame(updateLevels);
        }
        function stopLevelMeters() { if(levelRAF) cancelAnimationFrame(levelRAF); if(audioCtx){audioCtx.close();audioCtx=null;} localAnalyser=null; remoteAnalyser=null; document.getElementById("localLevel").style.height="0%"; document.getElementById("remoteLevel").style.height="0%"; }
        socket.on("connect", function(){ socket.emit("join",ROOM); document.getElementById("status").innerText="Waiting for peer..."; });
        socket.on("peer-joined", async function(){ document.getElementById("status").innerText="Peer connected!"; await setupMedia(); pc=createPC(); var o=await pc.createOffer(); await pc.setLocalDescription(o); socket.emit("offer",{room:ROOM,offer:o}); });
        socket.on("offer", async function(o){ await setupMedia(); pc=createPC(); await pc.setRemoteDescription(new RTCSessionDescription(o)); var a=await pc.createAnswer(); await pc.setLocalDescription(a); socket.emit("answer",{room:ROOM,answer:a}); startTimer(); });
        socket.on("answer", async function(a){ await pc.setRemoteDescription(new RTCSessionDescription(a)); document.getElementById("status").innerText="Call active"; startTimer(); });
        socket.on("ice", async function(c){ if(pc) await pc.addIceCandidate(new RTCIceCandidate(c)); });
        socket.on("peer-left", function(){ endCall(); document.getElementById("status").innerText="Peer disconnected"; });
        function createPC(){ var p=new RTCPeerConnection(iceConfig); localStream.getTracks().forEach(function(t){p.addTrack(t,localStream)}); p.ontrack=function(e){document.getElementById("remoteAudio").srcObject=e.streams[0];connectRemoteAnalyser(e.streams[0]);}; p.onicecandidate=function(e){if(e.candidate)socket.emit("ice",{room:ROOM,candidate:e.candidate});}; return p; }
        async function setupMedia(){ if(localStream)return; localStream=await navigator.mediaDevices.getUserMedia({video:false,audio:true}); startLevelMeters(); }
        async function startCall(){ await setupMedia(); document.getElementById("status").innerText="Waiting for peer..."; }
        function endCall(){ if(pc){pc.close();pc=null;} if(localStream){localStream.getTracks().forEach(function(t){t.stop()});localStream=null;} document.getElementById("remoteAudio").srcObject=null; stopTimer(); stopLevelMeters(); document.getElementById("status").innerText="Call ended"; }
        function toggleMute(){ if(!localStream)return; isMuted=!isMuted; localStream.getAudioTracks().forEach(function(t){t.enabled=!isMuted}); document.getElementById("muteBtn").innerText=isMuted?"Unmute":"Mute"; }
        function startTimer(){ seconds=0; timerInterval=setInterval(function(){ seconds++; var m=String(Math.floor(seconds/60)).padStart(2,"0"); var s=String(seconds%60).padStart(2,"0"); document.getElementById("timer").innerText=m+":"+s; },1000); }
        function stopTimer(){ clearInterval(timerInterval); document.getElementById("timer").innerText=""; }
    </script>
</body>
</html>
CALLEOF
docker cp /tmp/call.html anon_chat:/usr/src/app/html/call.html
echo -e "${GREEN}+ Custom UI + Calls${NC}"

# ---- AUTH SERVER ----
echo "Starting auth server..."
cat > /root/auth_server.js << AUTHEOF
const express = require('express')
const app = express()
const crypto = require('crypto')
const fs = require('fs')
app.use(express.json())
app.use(express.urlencoded({ extended: true }))
const tokens = new Set()
function getCurrentPassword() {
    try {
        const data = fs.readFileSync('/app/chat_credentials.txt', 'utf8')
        const match = data.match(/^user:(.+)$/m)
        return match ? match[1].trim() : null
    } catch(e) { return null }
}
app.get('/login', (req, res) => {
    res.send(\`<!DOCTYPE html><html><head><meta charset="utf-8"><title>Login</title><style>body{font-family:Monospace;background:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}.box{text-align:center}h2{margin-bottom:20px}input{border:1px solid #000;padding:8px;font-family:Monospace;font-size:14px;width:200px}button{background:#000;color:#fff;border:none;padding:8px 20px;cursor:pointer;font-family:Monospace;font-size:14px;margin-left:5px}.error{color:red;margin-top:10px;font-size:13px}</style></head><body><div class="box"><h2>Private Chat</h2><input type="password" id="pass" placeholder="Password" onkeydown="if(event.key==='Enter')login()"><button onclick="login()">Enter</button><div class="error" id="err"></div></div><script>async function login(){const p=document.getElementById('pass').value;const r=await fetch('/auth',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:p})});const d=await r.json();if(d.token){document.cookie='chat_token='+d.token+'; path=/';window.location.href='/'}else{document.getElementById('err').innerText='Wrong password'}}</script></body></html>\`)
})
app.post('/auth', (req, res) => {
    const { password } = req.body
    const correct = getCurrentPassword()
    if (password && correct && password === correct) {
        const token = crypto.randomBytes(32).toString('hex')
        tokens.add(token)
        setTimeout(() => tokens.delete(token), 24*60*60*1000)
        res.json({ token })
    } else { res.status(401).json({ error: 'Wrong password' }) }
})
app.get('/check', (req, res) => {
    const cookieHeader = req.headers.cookie || ''
    const match = cookieHeader.match(/chat_token=([^;]+)/)
    const token = match ? match[1] : null
    if (token && tokens.has(token)) { res.status(200).send('ok') }
    else { res.status(401).send('unauthorized') }
})
app.listen(4000, () => console.log('Auth server on port 4000'))
AUTHEOF

cd /root && npm install express 2>/dev/null || docker run --rm -v /root:/app -w /app node:18-alpine sh -c "npm install express 2>/dev/null"

docker run -d --name auth_server --network secure_net --restart unless-stopped \
  -v /root/auth_server.js:/app/auth_server.js \
  -v /root/chat_credentials.txt:/app/chat_credentials.txt \
  -v /root/node_modules:/app/node_modules \
  -w /app node:18-alpine node auth_server.js > /dev/null 2>&1
sleep 2
echo -e "${GREEN}+ Auth server${NC}"

# ---- SIGNAL SERVER ----
echo "Starting signal server..."
mkdir -p /root/calls
cat > /root/calls/signal.js << 'SIGEOF'
const express = require('express')
const app = express()
const http = require('http').Server(app)
const io = require('socket.io')(http)
io.on('connection', function(socket){
  socket.on('join', function(room){ socket.join(room); socket.broadcast.to(room).emit('peer-joined') })
  socket.on('offer', function(data){ socket.broadcast.to(data.room).emit('offer', data.offer) })
  socket.on('answer', function(data){ socket.broadcast.to(data.room).emit('answer', data.answer) })
  socket.on('ice', function(data){ socket.broadcast.to(data.room).emit('ice', data.candidate) })
  socket.on('disconnect', function(){ socket.broadcast.emit('peer-left') })
})
http.listen(3000, function(){ console.log('Signal server on port 3000') })
SIGEOF

cd /root/calls && npm install express socket.io 2>/dev/null || docker run --rm -v /root/calls:/app -w /app node:18-alpine sh -c "npm init -y && npm install express socket.io" > /dev/null 2>&1

docker run -d --name signal_server --network secure_net --restart unless-stopped \
  -v /root/calls:/app -w /app node:18-alpine node signal.js > /dev/null 2>&1
sleep 2
echo -e "${GREEN}+ Signal server${NC}"

# ---- COTURN ----
echo "Starting TURN server..."
docker run -d --name coturn --restart unless-stopped \
  -p 3478:3478/udp -p 3478:3478/tcp \
  coturn/coturn \
  --realm=$DOMAIN --user=chat:$TURN_PASS --lt-cred-mech --no-cli > /dev/null 2>&1
echo -e "${GREEN}+ TURN server${NC}"

# ---- NGINX ----
echo "Starting Nginx..."
cat > /root/nginx_secure/nginx.conf << 'NGEOF'
events { worker_connections 1024; }
http {
    server {
        listen 80;
        location /login {
            proxy_pass http://auth_server:4000/login;
            proxy_set_header Host $host;
        }
        location /auth {
            proxy_pass http://auth_server:4000/auth;
            proxy_set_header Host $host;
        }
        location /check {
            internal;
            proxy_pass http://auth_server:4000/check;
            proxy_set_header Cookie $http_cookie;
        }
        location /signal/ {
            proxy_pass http://signal_server:3000/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
        }
        location /socket.io/ {
            proxy_pass http://anon_chat:80/socket.io/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 3600s;
        }
        location / {
            auth_request /check;
            error_page 401 = @login_redirect;
            proxy_pass http://anon_chat:80/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            client_max_body_size 50M;
        }
        location @login_redirect {
            return 302 /login;
        }
    }
}
NGEOF

docker run -d --name secure_gateway --network secure_net --restart unless-stopped \
  -p 8080:80 \
  -v /root/nginx_secure/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v /root/nginx_secure/.htpasswd:/etc/nginx/.htpasswd:ro \
  nginx:alpine > /dev/null 2>&1
echo -e "${GREEN}+ Nginx${NC}"

# ---- CADDY ----
echo "Starting Caddy + HTTPS..."
docker run -d --name caddy --network secure_net --restart unless-stopped \
  -p 80:80 -p 443:443 \
  -v /root/caddy_data:/data \
  caddy:2-alpine caddy reverse-proxy \
  --from $DOMAIN --to secure_gateway:80 > /dev/null 2>&1
echo -e "${GREEN}+ Caddy HTTPS${NC}"

# ---- ROTATE PASSWORD SCRIPT ----
cat > /root/rotate_password.sh << ROTEOF
#!/bin/bash
TG_TOKEN="${TG_TOKEN}"
TG_CHAT_ID="${TG_CHAT_ID}"
NEW_PASS=\$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
LOGIN="user"
MD5_PASS=\$(openssl passwd -1 "\$NEW_PASS")
echo "\${LOGIN}:\${MD5_PASS}" > /root/nginx_secure/.htpasswd
echo "\${LOGIN}:\${NEW_PASS}" > /root/chat_credentials.txt
docker restart secure_gateway > /dev/null
MSG="Login: \${LOGIN}
Password: \${NEW_PASS}
Link: https://${DOMAIN}"
curl -s -X POST "https://api.telegram.org/bot\${TG_TOKEN}/sendMessage" \
  -d "chat_id=\${TG_CHAT_ID}" \
  --data-urlencode "text=\${MSG}"
echo ""
ROTEOF
chmod +x /root/rotate_password.sh

# ---- AUTO CLEAR ----
cat > /root/auto_clear.sh << 'CLREOF'
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
            /root/rotate_password.sh
            touch "$TRACK_FILE"
        fi
    fi
    sleep 60
done
CLREOF
chmod +x /root/auto_clear.sh

# ---- TELEGRAM BOT ----
cat > /root/tg_bot.py << BOTEOF
import subprocess
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
TG_TOKEN = "${TG_TOKEN}"
TG_CHAT_ID = ${TG_CHAT_ID}
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != TG_CHAT_ID:
        return
    keyboard = [[InlineKeyboardButton("Reset chat and change password", callback_data="reset")]]
    await update.message.reply_text("Chat management:", reply_markup=InlineKeyboardMarkup(keyboard))
async def button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    if query.from_user.id != TG_CHAT_ID:
        return
    await query.answer()
    await query.edit_message_text("Resetting chat...")
    subprocess.run(["docker", "restart", "anon_chat"])
    subprocess.run(["/root/rotate_password.sh"])
    await query.edit_message_text("Done! New password sent.")
app = Application.builder().token(TG_TOKEN).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CallbackQueryHandler(button))
app.run_polling()
BOTEOF

# ---- BACKUP / RESTORE ----
cat > /root/backup.sh << 'BKEOF'
#!/bin/bash
BACKUP_DIR="/root/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/chat_backup_$TIMESTAMP.tar.gz"
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_FILE /root/nginx_secure/ /root/auth_server.js /root/rotate_password.sh /root/auto_clear.sh /root/tg_bot.py /root/chat_credentials.txt /root/turn_credentials.txt /root/calls/ 2>/dev/null
echo "Backup: $BACKUP_FILE ($(du -sh $BACKUP_FILE | cut -f1))"
ls -t $BACKUP_DIR/chat_backup_*.tar.gz | tail -n +6 | xargs rm -f 2>/dev/null
BKEOF
chmod +x /root/backup.sh

cat > /root/restore.sh << 'RSEOF'
#!/bin/bash
BACKUP_DIR="/root/backups"
echo "Available backups:"
ls -t $BACKUP_DIR/chat_backup_*.tar.gz 2>/dev/null | nl
read -p "Enter number: " NUM
BACKUP_FILE=$(ls -t $BACKUP_DIR/chat_backup_*.tar.gz 2>/dev/null | sed -n "${NUM}p")
if [ -z "$BACKUP_FILE" ]; then echo "Not found"; exit 1; fi
tar -xzf $BACKUP_FILE -C / 2>/dev/null
docker restart anon_chat secure_gateway auth_server signal_server caddy
/root/rotate_password.sh > /dev/null
echo "Restored!"
RSEOF
chmod +x /root/restore.sh

# ---- CRON ----
(crontab -l 2>/dev/null; echo "@reboot nohup python3 /root/tg_bot.py > /var/log/tg_bot.log 2>&1 &") | crontab -
(crontab -l 2>/dev/null; echo "@reboot nohup /root/auto_clear.sh > /var/log/chat_auto_clear.log 2>&1 &") | crontab -
(crontab -l 2>/dev/null; echo "0 3 * * * /root/backup.sh > /var/log/backup.log 2>&1") | crontab -

# ---- START SERVICES ----
nohup /root/auto_clear.sh > /var/log/chat_auto_clear.log 2>&1 &
sleep 2
curl -s "https://api.telegram.org/bot${TG_TOKEN}/deleteWebhook?drop_pending_updates=true" > /dev/null
nohup python3 /root/tg_bot.py > /var/log/tg_bot.log 2>&1 &
sleep 3
/root/rotate_password.sh > /dev/null

echo ""
echo -e "${GREEN}"
echo "======================================"
echo "      Setup complete!                 "
echo "======================================"
echo -e "${NC}"
echo -e "Chat: ${GREEN}https://${DOMAIN}${NC}"
echo -e "Bot: send ${GREEN}/start${NC} to your bot"
echo -e "Password sent to Telegram"
echo ""
echo -e "${YELLOW}Wait 30-60 sec for SSL certificate${NC}"
