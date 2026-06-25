"""add forest_name and parcelle_name to assignments_cache

Revision ID: add_forest_parcelle_names
Revises: e4f5a6b7c8d9
Create Date: 2026-06-25 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "add_forest_parcelle_names"
down_revision: Union[str, None] = "e4f5a6b7c8d9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Ajouter forest_name et parcelle_name à assignments_cache"""
    op.add_column(
        "assignments_cache",
        sa.Column("forest_name", sa.String(255), nullable=True)
    )
    op.add_column(
        "assignments_cache",
        sa.Column("parcelle_name", sa.String(255), nullable=True)
    )


def downgrade() -> None:
    """Supprimer les colonnes en cas de rollback"""
    op.drop_column("assignments_cache", "forest_name")
    op.drop_column("assignments_cache", "parcelle_name")

