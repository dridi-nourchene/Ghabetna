# api_gateway/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from app.middlewares.auth_middleware import auth_middleware
from app.routers import auth_router, user_router

app = FastAPI(title="Ghabetna — API Gateway", version="1.0.0")

# ── Origins autorisées ────────────────────────────────────
ALLOWED_ORIGINS = [
    "http://localhost:8080",    # Flutter Web dev
    "http://localhost:3000",    # autre port possible
    "http://127.0.0.1:8080",
    "https://ghabetna.dz",      # production
    "https://app.ghabetna.dz",  # production
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(BaseHTTPMiddleware, dispatch=auth_middleware)

app.include_router(auth_router.router)
app.include_router(user_router.router)