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

// Get current password from file
function getPassword() {
  try {
    const data = fs.readFileSync("/app/credentials.txt", "utf8");
    const m = data.match(/^user:(.+)$/m);
    return m ? m[1].trim() : null;
  } catch(e) { return null; }
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
  const pass = req.body.password;
  const correct = getPassword();
  if (pass && correct && pass === correct) {
    const token = crypto.randomBytes(32).toString("hex");
    tokens.add(token);
    setTimeout(() => tokens.delete(token), 24 * 60 * 60 * 1000);
    return res.json({ ok: true, token });
  }
  res.status(401).json({ ok: false });
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

  socket.on("login", (data) => {
    const name = (data.nick || "").trim();
    if (!name) { socket.emit("force-login", "Nick cannot be empty"); return; }
    if (users[name]) { socket.emit("force-login", "Nick already taken"); return; }
    nick = name;
    users[nick] = socket.id;
    socket.join("chat");
    io.to("chat").emit("user-joined", { nick, users: Object.keys(users) });
    // No history - zero storage
  });

  socket.on("message", (data) => {
    if (!nick) return;
    const msg = { id: msgId++, from: nick, text: data.text, time: Date.now() };
    io.to("chat").emit("message", msg);
  });

  socket.on("file", (data) => {
    if (!nick) return;
    io.to("chat").emit("file", { from: nick, name: data.name, type: data.type, url: data.url, time: Date.now() });
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
