const express = require("express");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const app = express();
const http = require("http").Server(app);
const io = require("socket.io")(http, {
  maxHttpBufferSize: 52 * 1024 * 1024
});

const port = process.argv[2] || 80;
const tokens = new Set();
// No message caching - zero storage
const users = {};
let msgId = 1;

// Parse JSON
app.use(express.json());

// Rate limiting
const loginAttempts = {};
function isBlocked(ip) {
  const rec = loginAttempts[ip];
  if (!rec) return false;
  if (rec.blocked && Date.now() - rec.blockedAt < 5 * 60 * 1000) return true;
  if (rec.blocked && Date.now() - rec.blockedAt >= 5 * 60 * 1000) { delete loginAttempts[ip]; return false; }
  return false;
}
function addFail(ip) {
  if (!loginAttempts[ip]) loginAttempts[ip] = { fails: 0 };
  loginAttempts[ip].fails++;
  loginAttempts[ip].lastTry = Date.now();
  if (loginAttempts[ip].fails >= 3) { loginAttempts[ip].blocked = true; loginAttempts[ip].blockedAt = Date.now(); }
}
function resetFails(ip) { delete loginAttempts[ip]; }

// Очистка старых записей каждые 10 минут
setInterval(() => {
  const now = Date.now();
  for (const ip in loginAttempts) {
    const rec = loginAttempts[ip];
    if (rec.blocked && now - rec.blockedAt >= 5 * 60 * 1000) delete loginAttempts[ip];
    else if (!rec.blocked && now - (rec.lastTry || 0) >= 10 * 60 * 1000) delete loginAttempts[ip];
  }
}, 10 * 60 * 1000);

// Get current password from file
function getPasswordHash() {
  try {
    const data = fs.readFileSync("/app/credentials.txt", "utf8");
    const m = data.match(/^user:(.+)$/m);
    return m ? m[1].trim() : null;
  } catch(e) { return null; }
}

function hashPass(pass) {
  return crypto.createHash("sha256").update(pass).digest("hex");
}

// Check token from cookie
function checkToken(cookie) {
  if (!cookie) return false;
  const m = cookie.match(/chat_token=([^;]+)/);
  return m ? tokens.has(m[1]) : false;
}

// --- ROUTES ---

// Login page
app.get("/login", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "login.html"));
});

// Auth endpoint
app.post("/auth", (req, res) => {
  const ip = req.headers["x-real-ip"] || req.ip;
  if (isBlocked(ip)) return res.status(429).json({ ok: false, blocked: true, msg: "Too many attempts. Wait 5 minutes." });
  const pass = req.body.password;
  const correctHash = getPasswordHash();
  if (pass && correctHash && hashPass(pass) === correctHash) {
    resetFails(ip);
    const token = crypto.randomBytes(32).toString("hex");
    tokens.add(token);
    setTimeout(() => tokens.delete(token), 24 * 60 * 60 * 1000);
    res.cookie("chat_token", token, { httpOnly: true, secure: true, sameSite: "strict", path: "/", maxAge: 24*60*60*1000 });
    return res.json({ ok: true });
  }
  addFail(ip);
  const rec = loginAttempts[ip];
  if (rec && rec.blocked) return res.status(429).json({ ok: false, blocked: true, msg: "Too many attempts. Wait 5 minutes." });
  res.status(401).json({ ok: false, remaining: 3 - (rec ? rec.fails : 0) });
});

// Auth middleware for all other routes
app.use((req, res, next) => {
  if (checkToken(req.headers.cookie)) return next();
  res.redirect("/login");
});

// Static files (after auth check)
app.use(express.static(path.join(__dirname, "public")));

// --- SOCKET.IO ---

// Auth middleware for socket
io.use((socket, next) => {
  if (checkToken(socket.handshake.headers.cookie)) return next();
  next(new Error("unauthorized"));
});

io.on("connection", (socket) => {
  let nick = null;
  let lastMsgTime = 0;
  let lastFileTime = 0;

  socket.on("login", (data) => {
    const name = (data.nick || "").trim();
    if (!name) { socket.emit("force-login", "Nick cannot be empty"); return; }
    if (users[name]) { socket.emit("force-login", "Nick already taken"); return; }
    if (Object.keys(users).length >= 2) { socket.emit("force-login", "Chat is full (max 2)"); return; }
    nick = name;
    users[nick] = socket.id;
    socket.join("chat");
    io.to("chat").emit("user-joined", { nick, users: Object.keys(users) });
    // No history - zero storage
  });

  socket.on("message", (data) => {
    if (!nick) return;
    if (!data.text || data.text.length > 5000) return;
    if (Date.now() - lastMsgTime < 500) return;
    lastMsgTime = Date.now();
    const msg = { id: msgId++, from: nick, text: data.text.substring(0, 5000), time: Date.now() };
    io.to("chat").emit("message", msg);
  });

  socket.on("file", (data) => {
    if (!nick) return;
    if (!data.url || data.url.length > 70 * 1024 * 1024) return;
    if (Date.now() - lastFileTime < 10000) return;
    lastFileTime = Date.now();
    if (!data.name || data.name.length > 255) return;
    io.to("chat").emit("file", { from: nick, name: data.name.substring(0, 255), type: data.type, url: data.url, time: Date.now() });
  });

  socket.on("typing", (status) => {
    if (nick) socket.broadcast.to("chat").emit("typing", { nick, status });
  });

  // WebRTC signaling
  socket.on("call-offer", (d) => { socket.broadcast.to("chat").emit("call-offer", d); });
  socket.on("call-answer", (d) => { socket.broadcast.to("chat").emit("call-answer", d); });
  socket.on("ice-candidate", (d) => { socket.broadcast.to("chat").emit("ice-candidate", d); });
  socket.on("call-end", () => { socket.broadcast.to("chat").emit("call-end"); });

  socket.on("disconnect", () => {
    if (nick) {
      delete users[nick];
      io.to("chat").emit("user-left", { nick, users: Object.keys(users) });
      nick = null;
    }
  });
});

// Clear chat (called externally)
process.on("SIGUSR1", () => {
  io.to("chat").emit("chat-cleared");
  console.log("Chat cleared");
});

http.listen(port, () => console.log("Server running on port " + port));
