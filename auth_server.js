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
    } catch(e) {
        return null
    }
}

app.get('/login', (req, res) => {
    res.send(`<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Вход</title>
    <style>
        body { font-family: Monospace; background: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .box { text-align: center; }
        h2 { margin-bottom: 20px; }
        input { border: 1px solid #000; padding: 8px; font-family: Monospace; font-size: 14px; width: 200px; }
        button { background: #000; color: #fff; border: none; padding: 8px 20px; cursor: pointer; font-family: Monospace; font-size: 14px; margin-left: 5px; }
        .error { color: red; margin-top: 10px; font-size: 13px; }
    </style>
</head>
<body>
    <div class="box">
        <h2>Приватный чат</h2>
        <input type="password" id="pass" placeholder="Пароль" onkeydown="if(event.key==='Enter') login()">
        <button onclick="login()">Войти</button>
        <div class="error" id="err"></div>
    </div>
    <script>
        async function login() {
            const pass = document.getElementById('pass').value
            const res = await fetch('/auth', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({password: pass})
            })
            const data = await res.json()
            if(data.token) {
                document.cookie = 'chat_token=' + data.token + '; path=/'
                window.location.href = '/'
            } else {
                document.getElementById('err').innerText = 'Неверный пароль'
            }
        }
    </script>
</body>
</html>`)
})

app.post('/auth', (req, res) => {
    const { password } = req.body
    const correct = getCurrentPassword()
    console.log('Correct:', correct, 'Provided:', password)
    if (password && correct && password === correct) {
        const token = crypto.randomBytes(32).toString('hex')
        tokens.add(token)
        setTimeout(() => tokens.delete(token), 24 * 60 * 60 * 1000)
        res.json({ token })
    } else {
        res.status(401).json({ error: 'Wrong password' })
    }
})

app.get('/check', (req, res) => {
    const cookieHeader = req.headers.cookie || ''
    const match = cookieHeader.match(/chat_token=([^;]+)/)
    const token = match ? match[1] : null
    if (token && tokens.has(token)) {
        res.status(200).send('ok')
    } else {
        res.status(401).send('unauthorized')
    }
})

app.listen(4000, () => console.log('Auth server on port 4000'))
