from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
from app.core.config import settings

conf = ConnectionConfig(
    MAIL_USERNAME   = settings.MAIL_USERNAME,
    MAIL_PASSWORD   = settings.MAIL_PASSWORD,
    MAIL_FROM       = settings.MAIL_FROM,
    MAIL_PORT       = 587,
    MAIL_SERVER     = "smtp.gmail.com",
    MAIL_STARTTLS   = True,
    MAIL_SSL_TLS    = False,
    MAIL_FROM_NAME  = "Ghabetna DGF",
)

async def send_activation_email(to_email: str, to_name: str, token: str):
    activation_link = f"{settings.FRONTEND_URL}/activate?token={token}"

    message = MessageSchema(
        subject     = "Activation de votre compte Ghabetna",
        recipients  = [to_email],
        body        = f"""
        <h2>Bienvenue sur Ghabetna</h2>
        <p>Bonjour {to_name},</p>
        <p>Cliquez sur le lien pour activer votre compte :</p>
        <a href="{activation_link}">Activer mon compte</a>
        <p>Ce lien expire dans 24 heures.</p>
        <p>Direction Générale des Forêts</p>
        """,
        subtype     = MessageType.html,
    )

    fm = FastMail(conf)
    await fm.send_message(message)