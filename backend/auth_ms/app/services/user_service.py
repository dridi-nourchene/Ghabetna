import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID
from app.core.email import send_activation_email as send_email
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from fastapi import BackgroundTasks, HTTPException
from app.core.security import hash_password
from app.models.user import ActivationToken, User, UserRole, UserStatus
from app.schemas.user import UserCreate, UserUpdate


#  ────────────────────────────────────────────────────────────
# HELPER — stocker le token EN DB seulement (rapide)
# ────────────────────────────────────────────────────────────
async def _store_activation_token(user: User, db: AsyncSession) -> str:
    token = secrets.token_urlsafe(32)
    db.add(ActivationToken(
        user_id    = user.user_id,
        token      = token,
        expires_at = datetime.now(timezone.utc) + timedelta(hours=24),
        used       = False,
    ))
    await db.commit()
    print(f"[DEV] Token : {token}")
    return token
 
 
# ────────────────────────────────────────────────────────────
# HELPER — envoi email en background (hors transaction DB)
# ────────────────────────────────────────────────────────────
async def _send_activation_email(email: str, full_name: str, token: str) -> None:
    try:
        await send_email(to_email=email, to_name=full_name, token=token)
        print(f"[EMAIL] Envoyé à {email}")
    except Exception as e:
        print(f"[EMAIL ERROR] Échec envoi à {email} : {e}")
 
 
# ────────────────────────────────────────────────────────────
# CREATE USER — admin seulement
# ────────────────────────────────────────────────────────────
async def create_user(
    data:             UserCreate,
    current_user:     User,
    db:               AsyncSession,
    background_tasks: BackgroundTasks,
) -> User:
 
    if current_user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Seul l'admin peut créer des comptes")
 
    result = await db.execute(
        select(User).where(or_(User.cin == data.cin, User.email == data.email))
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="CIN ou email déjà utilisé")
 
    user = User(
        full_name     = data.full_name,
        email         = data.email,
        cin           = data.cin,
        phone         = data.phone,
        birth_date    = data.birth_date,
        role          = data.role,
        password_hash = None,
        status        = UserStatus.inactive,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
 
    # 1. Token en DB (~5ms)
    token = await _store_activation_token(user, db)
 
    # 2. Email en arrière-plan → réponse HTTP immédiate sans attendre Gmail
    background_tasks.add_task(_send_activation_email, user.email, user.full_name, token)
 
    return user
 
 
# ────────────────────────────────────────────────────────────
# ACTIVATE ACCOUNT
# ────────────────────────────────────────────────────────────
async def activate_account(token: str, new_password: str, db: AsyncSession) -> User:
    result = await db.execute(
        select(ActivationToken)
        .options(selectinload(ActivationToken.user))
        .where(ActivationToken.token == token)
    )
    db_token = result.scalar_one_or_none()
 
    if not db_token:
        raise HTTPException(status_code=400, detail="Lien d'activation invalide")
    if db_token.used:
        raise HTTPException(status_code=400, detail="Lien déjà utilisé")
    if db_token.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Lien expiré — demandez un nouveau lien")
 
    user               = db_token.user
    user.password_hash = hash_password(new_password)
    user.status        = UserStatus.active
    db_token.used      = True
 
    await db.commit()
    await db.refresh(user)
    return user
 
 
# ────────────────────────────────────────────────────────────
# GET USER BY ID
# ────────────────────────────────────────────────────────────
async def get_user_by_id(
    user_id: UUID,
    db:      AsyncSession,
) -> User:
    result = await db.execute(
        select(User).where(User.user_id == user_id)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=404,
            detail="User non trouvé"
        )
    return user


# ────────────────────────────────────────────────────────────
# GET ACTIVE USERS
# ────────────────────────────────────────────────────────────
async def get_active_users(db: AsyncSession) -> list[User]:
    result = await db.execute(
        select(User).where(User.status == UserStatus.active)
    )
    return result.scalars().all()


# ────────────────────────────────────────────────────────────
# GET INACTIVE USERS
# ────────────────────────────────────────────────────────────
async def get_inactive_users(db: AsyncSession) -> list[User]:
    result = await db.execute(
        select(User).where(User.status == UserStatus.inactive)
    )
    return result.scalars().all()


# ────────────────────────────────────────────────────────────
# UPDATE USER — admin seulement
# ────────────────────────────────────────────────────────────
async def update_user(
    user_id:      UUID,
    data:         UserUpdate,
    current_user: User,
    db:           AsyncSession,
) -> User:

    if current_user.role != UserRole.admin:
        raise HTTPException(
            status_code=403,
            detail="Seul l'admin peut modifier des comptes"
        )

    user = await get_user_by_id(user_id, db)

    if data.cin and data.cin != user.cin:
        result = await db.execute(
            select(User).where(User.cin == data.cin)
        )
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="CIN déjà utilisé")

    if data.email and data.email != user.email:
        result = await db.execute(
            select(User).where(User.email == data.email)
        )
        if result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Email déjà utilisé")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)

    return user


# ────────────────────────────────────────────────────────────
# DELETE USER — admin seulement
# ────────────────────────────────────────────────────────────
async def delete_user(
    user_id:      UUID,
    current_user: User,
    db:           AsyncSession,
) -> dict:

    if current_user.role != UserRole.admin:
        raise HTTPException(
            status_code=403,
            detail="Seul l'admin peut supprimer des comptes"
        )

    if current_user.user_id == user_id:
        raise HTTPException(
            status_code=400,
            detail="L'admin ne peut pas supprimer son propre compte"
        )

    user = await get_user_by_id(user_id, db)
    await db.delete(user)
    await db.commit()

    return {"message": f"User {user.full_name} supprimé avec succès"}