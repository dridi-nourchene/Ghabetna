"""ajout de la colonne source (agent / citoyen)

Revision ID: b7c8d9e0f1a2
Revises: a1b2c3d4e5f6
Create Date: 2026-08-25 10:00:00.000000

Distingue qui a émis le signalement sans toucher à agent_id : une seule
colonne, defaut 'agent' pour les lignes existantes, /api/alerts/mine
inchangé.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "b7c8d9e0f1a2"
down_revision: Union[str, None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

alertsource = sa.Enum("agent", "citoyen", name="alertsource")


def upgrade() -> None:
    alertsource.create(op.get_bind(), checkfirst=True)
    op.add_column(
        "alerts",
        sa.Column(
            "source",
            alertsource,
            nullable=False,
            server_default="agent",
        ),
    )


def downgrade() -> None:
    op.drop_column("alerts", "source")
    alertsource.drop(op.get_bind(), checkfirst=True)
