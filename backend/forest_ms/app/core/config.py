from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://postgres:master@localhost:5432/forest_db"
    SECRET_KEY:   str = "dev-secret-key"
    PORT:         int = 8002

    model_config = {"env_file": ".env"}


settings = Settings()