"""ajout des 3 types d'alerte manquants

Revision ID: a1b2c3d4e5f6
Revises: f5a6b7c8d9e0
Create Date: 2026-08-22 10:00:00.000000
"""
from typing import Sequence, Union

from alembic import op

revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, None] = "f5a6b7c8d9e0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

NOUVELLES_VALEURS = (
    "depot_dechets",
    "chasse_illegale",
    "activite_suspecte",
)


def upgrade() -> None:
    for valeur in NOUVELLES_VALEURS:
        op.execute(f"ALTER TYPE alerttype ADD VALUE IF NOT EXISTS '{valeur}'")


def downgrade() -> None:
    pass