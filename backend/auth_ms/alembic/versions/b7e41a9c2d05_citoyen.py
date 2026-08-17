"""ajout role citoyen, specialite et statuts en_attente/rejete

Revision ID: b7e41a9c2d05
Revises: 6df00c5fd1f4
Create Date: 2026-08-16 10:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b7e41a9c2d05'
down_revision: Union[str, None] = '6df00c5fd1f4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Nouvelles valeurs des enums existants ─────────────
    # IF NOT EXISTS : rend la migration rejouable si j'ai déjà passé des
    # ALTER TYPE à la main en debug.
    op.execute("ALTER TYPE userrole   ADD VALUE IF NOT EXISTS 'citoyen'")
    op.execute("ALTER TYPE userstatus ADD VALUE IF NOT EXISTS 'en_attente'")
    op.execute("ALTER TYPE userstatus ADD VALUE IF NOT EXISTS 'rejete'")

    # ── Nouveau type specialite ───────────────────────────
    # create_type=False sur la colonne plus bas : je crée le type ici
    # explicitement, sinon SQLAlchemy essaie de le recréer et échoue.
    specialite = sa.Enum('chasseur', 'campeur', 'apiculteur', name='specialite')
    specialite.create(op.get_bind(), checkfirst=True)

    op.add_column(
        'users',
        sa.Column(
            'specialite',
            sa.Enum('chasseur', 'campeur', 'apiculteur',
                    name='specialite', create_type=False),
            nullable=True,
        ),
    )

    # ── Contrainte : un citoyen doit avoir une spécialité ─
    # role::text et pas role : PostgreSQL refuse d'utiliser une valeur d'enum
    # ajoutée dans la MÊME transaction ("unsafe use of new value"). Le cast en
    # texte contourne ça — la comparaison porte sur la chaîne, pas sur l'enum.
    op.create_check_constraint(
        'ck_users_citoyen_specialite',
        'users',
        "role::text <> 'citoyen' OR specialite IS NOT NULL",
    )


def downgrade() -> None:
    op.drop_constraint('ck_users_citoyen_specialite', 'users', type_='check')
    op.drop_column('users', 'specialite')
    op.execute("DROP TYPE IF EXISTS specialite")

    # PostgreSQL ne sait pas retirer une valeur d'un enum : citoyen,
    # en_attente et rejete restent dans userrole / userstatus. Sans
    # importance, aucune ligne ne les utilise après ce downgrade.