"""
Crée le premier compte administrateur.

Nécessaire parce que create_user() refuse tant qu'aucun admin n'existe :
« Seul l'admin peut créer des comptes ». L'œuf et la poule — il faut donc
un point d'entrée hors API pour amorcer la base.

Passe par le code de l'application et non par du SQL : hash_password garantit
le format bcrypt attendu par verify_password, et UserRole/UserStatus évitent
d'écrire à la main les valeurs des types énumérés PostgreSQL.

Idempotent : relancer ne crée pas de doublon, ce qui est pratique après
chaque remise à zéro de la base.
"""

import asyncio

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.core.config import settings
from app.core.security import hash_password
from app.models.user import User, UserRole, UserStatus

EMAIL      = "admin@ghabetna.tn"
MOT_DE_PASSE = "Admin1234*"
NOM        = "Admin DGF"
CIN        = "11447319"
TELEPHONE  = "22108261"


async def main() -> None:
    engine = create_async_engine(settings.DATABASE_URL)

    async with AsyncSession(engine) as db:
        existant = await db.execute(select(User).where(User.email == EMAIL))
        if existant.scalar_one_or_none():
            print(f"Déjà présent : {EMAIL}")
            await engine.dispose()
            return

        db.add(User(
            full_name     = NOM,
            email         = EMAIL,
            cin           = CIN,
            phone         = TELEPHONE,
            role          = UserRole.admin,
            # active et non inactive : le flux normal passe par un email
            # d'activation, dont on n'a pas besoin ici.
            status        = UserStatus.active,
            password_hash = hash_password(MOT_DE_PASSE),
        ))
        await db.commit()

    await engine.dispose()
    print(f"Admin créé — {EMAIL} / {MOT_DE_PASSE}")


asyncio.run(main())