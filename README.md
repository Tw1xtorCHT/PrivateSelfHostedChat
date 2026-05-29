# PrivateSelfHostedChat

Приватный самохостируемый чат с голосовыми звонками, автосменой паролей и управлением через Telegram.

## Возможности

- Анонимный чат без регистрации
- P2P голосовые звонки (WebRTC)
- Токен-авторизация через страницу входа
- Автосмена пароля каждый час
- Telegram бот с кнопкой сброса
- Передача файлов до 50 МБ
- HTTPS с автосертификатом
- Бэкап и восстановление одной командой

## Требования

- Ubuntu 20.04 / 22.04 / 24.04
- VPS с 1 ГБ RAM
- Домен (бесплатно на [duckdns.org](https://duckdns.org))
- Telegram бот ([@BotFather](https://t.me/BotFather))
- Ваш Chat ID ([@userinfobot](https://t.me/userinfobot))

## Установка

```bash
curl -fsSL https://raw.githubusercontent.com/Tw1xtorCHT/PrivateSelfHostedChat/main/install.sh | bash
```

Скрипт спросит:
- Токен Telegram бота
- Ваш Chat ID
- Домен

Всё остальное установится автоматически за 3 минуты.

## Управление

### Telegram бот
Напишите боту `/start` — кнопка сброса чата и смены пароля.

### Команды на сервере

Сбросить чат и сменить пароль:
```bash
/root/rotate_password.sh
```

Бэкап:
```bash
/root/backup.sh
```

Восстановление:
```bash
/root/restore.sh
```

## Архитектура
## Безопасность

- Сообщения только в оперативной памяти
- При перезапуске всё стирается
- Открытый код без бэкдоров
- P2P звонки — сервер не слышит разговор
- Уровень защиты как в обычных чатах Telegram

## Благодарности

- [m1k1o/chat](https://github.com/m1k1o/chat) — движок чата (Socket.io, Node.js)
- [Caddy](https://caddyserver.com) — автоматический HTTPS
- [coturn](https://github.com/coturn/coturn) — TURN сервер для звонков

## Лицензия

GPL-3.0
