import os
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY         = os.getenv("SECRET_KEY")
ALGORITHM          = os.getenv("ALGORITHM", "HS256")
USER_SERVICE_URL   = os.getenv("USER_SERVICE_URL", "http://localhost:8001")
FOREST_SERVICE_URL = os.getenv("FOREST_SERVICE_URL", "http://localhost:8002")

# Routes publiques — pas besoin de JWT
PUBLIC_ROUTES = [
    ("/api/auth/login",    "POST"),
    ("/api/auth/refresh",  "POST"),
    ("/api/users/activate","POST"),
]