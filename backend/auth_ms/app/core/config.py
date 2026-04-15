from pydantic_settings import BaseSettings
from typing import List
from pydantic import ConfigDict

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str

    # JWT
    JWT_SECRET_KEY: str
    JWT_REFRESH_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # App
    ALLOWED_ORIGINS: List[str] = ["*"]
    FRONTEND_URL: str = "http://localhost:3000"

    # Redis
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379

    # Mail
    MAIL_HOST: str
    MAIL_PORT: int = 587
    MAIL_USERNAME: str
    MAIL_PASSWORD: str
    MAIL_FROM: str

    model_config = ConfigDict(env_file=".env", extra="ignore")
  
settings = Settings()

