from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://analytics_user:analytics_pass@analytics_db:5432/analytics_db"
    SECRET_KEY:   str = "dev-secret-key"
    PORT:         int = 8004

    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()