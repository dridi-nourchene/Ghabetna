from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://alert_user:alert_pass@alert_db:5432/alert_db"
    SECRET_KEY:   str = "dev-secret-key"
    PORT:         int = 8003
    # URL de base pour construire les liens images
    BASE_URL:     str = ""

    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    
    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()