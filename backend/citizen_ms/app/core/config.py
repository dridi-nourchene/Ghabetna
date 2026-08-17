from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://citizen_user:citizen_pass@citizen_db:5432/citizen_db"
    SECRET_KEY:   str = "dev-secret-key"
    PORT:         int = 8006

    # URL de base pour construire les liens vers les pièces jointes,
    # même logique que BASE_URL dans alert_ms.
    BASE_URL:     str = ""

    # Appel direct au conteneur, sans passer par la gateway : ce nom n'existe
    # que dans le réseau ghabetna_net, donc la route interne d'auth_ms reste
    # injoignable depuis l'extérieur.
    AUTH_SERVICE_URL: str = "http://auth_ms:8001"

    # Délai max pour l'appel à auth_ms. Sans timeout explicite, une requête
    # d'inscription resterait suspendue indéfiniment si auth_ms se bloque.
    AUTH_TIMEOUT: float = 10.0

    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
