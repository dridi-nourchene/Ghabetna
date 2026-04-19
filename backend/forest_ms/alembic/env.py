import os
import sys
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

# ── Ajouter le répertoire racine au path ──────────────────
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# ── Importer les DEUX modèles ─────────────────────────────
# L'ordre est important : Forest d'abord (Parcelle dépend de Forest via FK)
from app.models.forest import Forest       # noqa: F401
from app.models.parcelle import Parcelle   # noqa: F401
from app.db.database import Base

# ── GeoAlchemy2 — nécessaire pour que Alembic reconnaisse
#    le type Geometry et génère le bon DDL PostGIS ─────────
import geoalchemy2  # noqa: F401

# ── Config Alembic ────────────────────────────────────────
config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

# ── URL DB — priorité à la variable d'environnement ──────
def get_url() -> str:
    """
    On utilise une URL *synchrone* (psycopg2) pour Alembic,
    même si l'application tourne en asyncpg.
    """
    url = os.getenv(
        "DATABASE_URL_SYNC",
        "postgresql+psycopg2://postgres:master@localhost:5432/forest_db",
    )
    # Sécurité : si quelqu'un passe l'URL asyncpg, on corrige
    return url.replace("postgresql+asyncpg://", "postgresql+psycopg2://")


# ── Mode OFFLINE ──────────────────────────────────────────
def run_migrations_offline() -> None:
    """
    Génère le SQL sans connexion réelle à la DB.
    Utile pour audits ou environnements sans accès direct.
    """
    url = config.get_main_option("sqlalchemy.url") or get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        # Important pour GeoAlchemy2 :
        # render_as_batch=False  (défaut, OK pour PostgreSQL)
    )
    with context.begin_transaction():
        context.run_migrations()


# ── Mode ONLINE (synchrone) ───────────────────────────────
def run_migrations_online() -> None:
    """
    Connexion synchrone via psycopg2.
    NullPool recommandé pour les migrations (pas de pool persistant).
    """
    # Injecter l'URL dans la config si non définie dans alembic.ini
    configuration = config.get_section(config.config_ini_section, {})
    if not configuration.get("sqlalchemy.url"):
        configuration["sqlalchemy.url"] = get_url()

    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )
        with context.begin_transaction():
            context.run_migrations()


# ── Point d'entrée ────────────────────────────────────────
if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()