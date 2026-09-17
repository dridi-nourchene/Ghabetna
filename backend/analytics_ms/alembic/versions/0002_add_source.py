"""add source column to alert_facts

Distingue un signalement d'agent d'un signalement citoyen. Sans cette
colonne, analytics_ms cherche l'auteur dans users_cache — l'annuaire du
seul personnel — et affiche « Inconnu » pour tout citoyen.

server_default="agent" plutôt que nullable=True : les lignes déjà en base
datent d'avant l'ouverture aux usagers de la forêt, elles proviennent donc
bien d'agents. Celles qui viendraient de citoyens sont corrigées par le
script de rattrapage, alert_ms restant la source de vérité.

Revision ID: 0002_add_source
Revises: 0001_create_alert_facts
Create Date: 2026-09-11 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0002_add_source"
down_revision: Union[str, None] = "0001_create_alert_facts"
branch_labels = None
depends_on    = None


def upgrade() -> None:
    op.add_column(
        "alert_facts",
        sa.Column("source", sa.String(20), nullable=False, server_default="agent"),
    )
    op.create_index("idx_alert_facts_source", "alert_facts", ["source"])


def downgrade() -> None:
    op.drop_index("idx_alert_facts_source", table_name="alert_facts")
    op.drop_column("alert_facts", "source")
