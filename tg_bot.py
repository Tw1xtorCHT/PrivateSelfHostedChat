import subprocess
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes

TG_TOKEN = "YOUR_BOT_TOKEN"
TG_CHAT_ID = YOUR_CHAT_ID

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != TG_CHAT_ID:
        return
    keyboard = [[InlineKeyboardButton("🔄 Сбросить чат и обновить пароль", callback_data="reset")]]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await update.message.reply_text("Управление приватным чатом:", reply_markup=reply_markup)

async def button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    if query.from_user.id != TG_CHAT_ID:
        return
    await query.answer()
    await query.edit_message_text("⏳ Сбрасываю чат и генерирую новый пароль...")
    subprocess.run(["docker", "restart", "anon_chat"])
    subprocess.run(["/root/rotate_chat_access.sh"])
    await query.edit_message_text("✅ Готово! Новый пароль отправлен.")

app = Application.builder().token(TG_TOKEN).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CallbackQueryHandler(button))
app.run_polling()
