import subprocess
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes

TG_TOKEN = "YOUR_BOT_TOKEN"
TG_CHAT_ID = YOUR_CHAT_ID

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
    subprocess.run(["docker", "restart", "pschat"])
    subprocess.run(["/root/rotate_chat_access.sh"])
    await query.edit_message_text("Done! New password sent.")

app = Application.builder().token(TG_TOKEN).build()
app.add_handler(CommandHandler("start", start))
app.add_handler(CallbackQueryHandler(button))
app.run_polling()
