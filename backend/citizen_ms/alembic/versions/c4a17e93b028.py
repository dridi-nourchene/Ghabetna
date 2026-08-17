"""initial citizen

Revision ID: c4a17e93b028
Revises: 
Create Date: 2026-08-16 12:00:00.000000

Écrite à la main. Points d'attention :

  - Les types enum sont créés EXPLICITEMENT en premier, avec create_type=False
    sur les colonnes. Sans ça, SQLAlchemy tente de recréer le même type à
    chaque table qui l'utilise et échoue sur "type already exists".

  - L'ordre de création compte : profils_citoyens avant ses tables filles,
    profils_apiculteurs avant ruchers. Une FK vers une table absente échoue.

  - Le downgrade fait l'inverse strict, tables filles d'abord, puis les types.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'c4a17e93b028'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# ── Types enum, déclarés une fois et réutilisés ───────────
specialite = postgresql.ENUM(
    'chasseur', 'campeur', 'apiculteur',
    name='specialite', create_type=False,
)
statut_dossier = postgresql.ENUM(
    'en_attente', 'approuve', 'rejete',
    name='statutdossier', create_type=False,
)
type_document = postgresql.ENUM(
    'cin_recto', 'cin_verso', 'permis_chasse', 'permis_detention',
    'permis_port_transport', 'certificat_colonies',
    name='typedocument', create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()

    # checkfirst=True : la migration reste rejouable si un type traîne d'un
    # essai précédent.
    specialite.create(bind, checkfirst=True)
    statut_dossier.create(bind, checkfirst=True)
    type_document.create(bind, checkfirst=True)

    # ── profils_citoyens ──────────────────────────────────
    op.create_table(
        'profils_citoyens',
        sa.Column('profil_id',      sa.UUID(), nullable=False),
        # Pas de ForeignKey : user_id référence auth_ms, une autre base.
        # L'unicité reste utile — un compte ne peut avoir qu'un dossier.
        sa.Column('user_id',        sa.UUID(), nullable=False),
        sa.Column('specialite',     specialite, nullable=False),
        sa.Column('statut_dossier', statut_dossier, nullable=False),
        sa.Column('gouvernorat',    sa.String(length=100), nullable=False),
        sa.Column('delegation',     sa.String(length=100), nullable=False),
        sa.Column('secteur',        sa.String(length=100), nullable=True),
        sa.Column('adresse',        sa.Text(), nullable=True),
        sa.Column('telephone',      sa.String(length=20), nullable=True),
        sa.Column('motif_rejet',    sa.Text(), nullable=True),
        sa.Column('soumis_le',      sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=True),
        sa.Column('traite_le',      sa.DateTime(timezone=True), nullable=True),
        sa.Column('traite_par',     sa.UUID(), nullable=True),
        sa.CheckConstraint(
            "statut_dossier::text <> 'rejete' OR motif_rejet IS NOT NULL",
            name='ck_profil_motif_si_rejete'
        ),
        sa.PrimaryKeyConstraint('profil_id'),
        sa.UniqueConstraint('user_id'),
    )
    op.create_index('ix_profils_citoyens_user_id', 'profils_citoyens', ['user_id'])

    # ── pieces_jointes ────────────────────────────────────
    op.create_table(
        'pieces_jointes',
        sa.Column('piece_id',      sa.UUID(), nullable=False),
        sa.Column('profil_id',     sa.UUID(), nullable=False),
        sa.Column('type_document', type_document, nullable=False),
        # Chemin uniquement : le fichier vit sur le volume, pas en base.
        sa.Column('chemin',        sa.String(length=500), nullable=False),
        sa.Column('mime_type',     sa.String(length=100), nullable=False),
        sa.Column('taille_octets', sa.Integer(), nullable=False),
        sa.Column('televerse_le',  sa.DateTime(timezone=True),
                  server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['profil_id'], ['profils_citoyens.profil_id'],
                                ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('piece_id'),
    )
    op.create_index('ix_pieces_jointes_profil_id', 'pieces_jointes', ['profil_id'])

    # ── profils_chasseurs ─────────────────────────────────
    op.create_table(
        'profils_chasseurs',
        sa.Column('profil_id',                    sa.UUID(), nullable=False),
        sa.Column('numero_permis_chasse',         sa.String(length=50), nullable=False),
        sa.Column('date_delivrance',              sa.Date(), nullable=True),
        sa.Column('date_expiration',              sa.Date(), nullable=True),
        sa.Column('gouvernorat_delivrance',       sa.String(length=100), nullable=True),
        sa.Column('possede_arme',                 sa.Boolean(), nullable=False),
        sa.Column('numero_permis_detention',      sa.String(length=50), nullable=True),
        sa.Column('numero_permis_port_transport', sa.String(length=50), nullable=True),
        # Loi 69-33 : une arme détenue sans droit de transport ne peut pas
        # servir à la chasse — les deux permis vont ensemble.
        sa.CheckConstraint(
            "possede_arme = false OR ("
            " numero_permis_detention IS NOT NULL AND"
            " numero_permis_port_transport IS NOT NULL)",
            name='ck_chasseur_permis_arme'
        ),
        sa.ForeignKeyConstraint(['profil_id'], ['profils_citoyens.profil_id'],
                                ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('profil_id'),
    )

    # ── profils_apiculteurs ───────────────────────────────
    # Annexe 16 de l'arrêté du 31 décembre 2015 : code de 8 chiffres
    # découpé en apiculteur (4) + délégation (2) + gouvernorat (2).
    op.create_table(
        'profils_apiculteurs',
        sa.Column('profil_id',               sa.UUID(), nullable=False),
        sa.Column('code_apiculteur',         sa.String(length=4), nullable=False),
        sa.Column('code_delegation',         sa.String(length=2), nullable=False),
        sa.Column('code_gouvernorat',        sa.String(length=2), nullable=False),
        sa.Column('nombre_colonies_declare', sa.Integer(), nullable=False),
        sa.Column('date_certificat',         sa.Date(), nullable=True),
        sa.CheckConstraint("code_apiculteur  ~ '^[0-9]{4}$'", name='ck_api_code_apiculteur'),
        sa.CheckConstraint("code_delegation  ~ '^[0-9]{2}$'", name='ck_api_code_delegation'),
        sa.CheckConstraint("code_gouvernorat ~ '^[0-9]{2}$'", name='ck_api_code_gouvernorat'),
        sa.ForeignKeyConstraint(['profil_id'], ['profils_citoyens.profil_id'],
                                ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('profil_id'),
    )

    # ── ruchers ───────────────────────────────────────────
    # emplacement est le champ officiel (annexes 18 et 21, texte libre).
    # latitude/longitude sont un ajout applicatif, nullable : ils serviront
    # à croiser les ruchers avec les parcelles et les alertes incendie.
    op.create_table(
        'ruchers',
        sa.Column('rucher_id',       sa.UUID(), nullable=False),
        sa.Column('profil_id',       sa.UUID(), nullable=False),
        sa.Column('numero_rucher',   sa.Integer(), nullable=False),
        sa.Column('emplacement',     sa.String(length=255), nullable=False),
        sa.Column('latitude',        sa.Float(), nullable=True),
        sa.Column('longitude',       sa.Float(), nullable=True),
        sa.Column('nombre_colonies', sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(['profil_id'], ['profils_apiculteurs.profil_id'],
                                ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('rucher_id'),
    )
    op.create_index('ix_ruchers_profil_id', 'ruchers', ['profil_id'])


def downgrade() -> None:
    # Ordre inverse strict : les tables filles avant les parents, sinon les
    # contraintes de clé étrangère bloquent la suppression.
    op.drop_index('ix_ruchers_profil_id', table_name='ruchers')
    op.drop_table('ruchers')
    op.drop_table('profils_apiculteurs')
    op.drop_table('profils_chasseurs')
    op.drop_index('ix_pieces_jointes_profil_id', table_name='pieces_jointes')
    op.drop_table('pieces_jointes')
    op.drop_index('ix_profils_citoyens_user_id', table_name='profils_citoyens')
    op.drop_table('profils_citoyens')

    bind = op.get_bind()
    type_document.drop(bind, checkfirst=True)
    statut_dossier.drop(bind, checkfirst=True)
    specialite.drop(bind, checkfirst=True)