const express = require('express')
const app = express()
const http = require('http').Server(app)
const io = require('socket.io')(http)
const path = require('path')

app.use(express.static(path.join(__dirname, 'public')))

io.on('connection', function(socket){
  socket.on('join', function(room){
    socket.join(room)
    socket.broadcast.to(room).emit('peer-joined')
  })
  socket.on('offer', function(data){ socket.broadcast.to(data.room).emit('offer', data.offer) })
  socket.on('answer', function(data){ socket.broadcast.to(data.room).emit('answer', data.answer) })
  socket.on('ice', function(data){ socket.broadcast.to(data.room).emit('ice', data.candidate) })
  socket.on('disconnect', function(){ socket.broadcast.emit('peer-left') })
})

http.listen(3000, function(){ console.log('Signal server on port 3000') })
