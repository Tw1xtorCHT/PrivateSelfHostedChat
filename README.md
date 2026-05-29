# PrivateSelfHostedChat

Private self-hosted chat with P2P voice calls, auto-rotating passwords and Telegram bot management.

Built from scratch on Node.js + Socket.io + WebRTC.

## Features

- Anonymous chat - no registration, no accounts
- P2P voice calls (WebRTC) with audio level indicators
- Token-based authentication
- Auto-rotating password every hour
- Telegram bot with one-tap reset
- File sharing up to 50 MB (drag and drop)
- HTTPS with automatic Let's Encrypt certificate
- Zero disk storage - everything in RAM only
- Auto-kick users on password change
- Backup and restore

## Architecture

```
Browser -> Caddy (HTTPS) -> Nginx -> PSChat (auth + chat + calls)
Calls -> WebRTC P2P (direct between browsers)
TURN -> Coturn (fallback)
Bot -> Telegram -> auto-reset every hour
```

Only 4 containers: pschat, nginx, caddy, coturn.

## Requirements

- Ubuntu 20.04 / 22.04 / 24.04
- VPS with 1 GB RAM
- Domain (free at [duckdns.org](https://duckdns.org))
- Telegram bot ([@BotFather](https://t.me/BotFather))
- Your Chat ID ([@userinfobot](https://t.me/userinfobot))

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Tw1xtorCHT/PrivateSelfHostedChat/main/install.sh | bash
```

The script asks for bot token, Chat ID and domain. Everything else is automatic.

## Management

Send `/start` to your Telegram bot for a reset button.

```bash
/root/rotate_password.sh  # new password
/root/backup.sh           # backup
```

## Security

- Messages and files in RAM only
- Full wipe on restart
- Open source, no backdoors
- P2P calls - server never hears audio
- Auto-kick on password change

## Credits

- [Caddy](https://caddyserver.com) - automatic HTTPS
- [coturn](https://github.com/coturn/coturn) - TURN server

## License

MIT
