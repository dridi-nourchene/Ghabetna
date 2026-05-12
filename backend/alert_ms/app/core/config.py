from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://postgres:master@localhost:5432/alert_db"
    SECRET_KEY:   str = "dev-secret-key"
    PORT:         int = 8003
    # URL de base pour construire les liens images
    BASE_URL:     str = "http://localhost:8003"

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()