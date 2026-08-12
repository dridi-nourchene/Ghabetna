import os
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY         = os.getenv("SECRET_KEY")
ALGORITHM          = os.getenv("ALGORITHM", "HS256")
USER_SERVICE_URL   = os.getenv("USER_SERVICE_URL", "http://auth_ms:8001")
FOREST_SERVICE_URL = os.getenv("FOREST_SERVICE_URL", "http://forest_ms:8002")
ALERT_SERVICE_URL = os.getenv("ALERT_SERVICE_URL", "http://alert_ms:8003")
ANALYTICS_SERVICE_URL = os.getenv("ANALYTICS_SERVICE_URL", "http://analytics_ms:8004")
CHATBOT_SERVICE_URL = os.getenv("CHATBOT_SERVICE_URL", "http://chatbot_ms:8005")

# Routes publiques — pas besoin de JWT
PUBLIC_ROUTES = [
    ("/api/auth/login",    "POST"),
    ("/api/auth/refresh",  "POST"),
    ("/api/users/activate","POST"),
    ("/api/chat/", "POST"),
]