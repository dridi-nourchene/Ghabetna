from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://postgres:master@localhost:5432/forest_db"
    SECRET_KEY:   str = "dev-secret-key"
    PORT:         int = 8002

    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()