# PrivateSelfHostedChat

Private self-hosted chat with voice calls, auto-rotating passwords and Telegram bot management. Deploy on any VPS in 3 minutes with a single command.

## Features

- Anonymous chat - no registration, no accounts
- P2P voice calls (WebRTC) - server never hears the conversation
- Token-based authentication with custom login page
- Auto-rotating password every hour
- Telegram bot with one-tap chat reset
- File sharing up to 50 MB
- HTTPS with automatic Let's Encrypt certificate
- Backup and restore with a single command

## Requirements

- Ubuntu 20.04 / 22.04 / 24.04
- VPS with 1 GB RAM
- Domain (free at [duckdns.org](https://duckdns.org))
- Telegram bot ([@BotFather](https://t.me/BotFather))
- Your Chat ID ([@userinfobot](https://t.me/userinfobot))

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Tw1xtorCHT/PrivateSelfHostedChat/main/install.sh | bash
```

The script will ask for:
- Telegram bot token
- Your Chat ID
- Domain name

Everything else installs automatically in about 3 minutes.

## Management

### Telegram bot
Send `/start` to your bot to get a button for resetting the chat and generating a new password.

### Server commands

Reset chat and change password:
```bash
/root/rotate_password.sh
```

Backup:
```bash
/root/backup.sh
```

Restore:
```bash
/root/restore.sh
```

## Architecture

```
Browser -> HTTPS (Caddy) -> Nginx -> Auth Server (token check)
                                  -> Chat (m1k1o/chat)
                                  -> Signal Server (calls)
Calls -> WebRTC P2P (direct between browsers)
TURN -> Coturn (fallback if P2P fails)
Management -> Telegram Bot -> auto-reset every hour
```

## Security

- Messages stored in RAM only, nothing written to disk
- Full wipe on container restart
- Open source, no backdoors, no analytics, no trackers
- P2P calls, server only connects peers, never hears audio
- Protection level comparable to standard Telegram chats

## Credits

- [m1k1o/chat](https://github.com/m1k1o/chat) - chat engine (Socket.io, Node.js)
- [Caddy](https://caddyserver.com) - automatic HTTPS
- [coturn](https://github.com/coturn/coturn) - TURN server for calls

## License

GPL-3.0
