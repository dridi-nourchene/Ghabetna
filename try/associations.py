from sqlalchemy import Table, Column, ForeignKey
from sqlalchemy.dialects.postgresql import UUID

from app.db.database import Base


# role_permissions  (Many-to-Many)
# Pas de classe SQLAlchemy ici — juste une Table simple
# car cette table n'a pas besoin d'attributs supplémentaires
#  fait juste le lien entre roles et permissions

role_permissions = Table("role_permissions",Base.metadata,

    # FK vers roles.role_id
    Column("role_id",UUID(as_uuid=True),ForeignKey("roles.role_id", ondelete="CASCADE"),primary_key=True,),

    # FK vers permissions.perm_id
    Column("perm_id",UUID(as_uuid=True),ForeignKey("permissions.perm_id", ondelete="CASCADE"),primary_key=True,),
)