from uuid import UUID
from app.core.redis_client import get_redis
from fastapi import APIRouter, BackgroundTasks, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
import redis.asyncio as aioredis
from app.core.dependencies import require_admin
from app.db.database import get_db
from app.models.user import User
from app.schemas.user import UserActivate, UserCreate, UserResponse, UserUpdate
from app.services import user_service
from app.models.user import User, UserStatus

router = APIRouter(prefix="/api/users", tags=["Users"])


@router.post("/", response_model=UserResponse, status_code=201,
             summary="Créer un user (admin seulement)")
async def create_user(
    data:             UserCreate,
    background_tasks: BackgroundTasks,
    db:               AsyncSession = Depends(get_db),
    current_user:     User         = Depends(require_admin),
):
    return await user_service.create_user(
        data=data, current_user=current_user,
        db=db, background_tasks=background_tasks,
    )


 
@router.post("/activate", response_model=UserResponse,
             summary="Activer le compte et définir le mot de passe")
async def activate_account(
    data:  UserActivate,
    db:    AsyncSession      = Depends(get_db),
    redis: aioredis.Redis    = Depends(get_redis),
):
    """
    Active le compte utilisateur.
    Vérifie que Redis est disponible AVANT de committer (spec architecture).
    Publie l'événement sur stream:user.activated après activation.
    """
    return await user_service.activate_account(
        token=data.token,
        new_password=data.password,
        db=db,
        redis=redis,
    )

@router.get("/active", response_model=list[UserResponse])
async def get_active_users(
    db:           AsyncSession = Depends(get_db),
    current_user: User         = Depends(require_admin),
):
    return await user_service.get_active_users(db)


@router.get("/inactive", response_model=list[UserResponse])
async def get_inactive_users(
    db:           AsyncSession = Depends(get_db),
    current_user: User         = Depends(require_admin),
):
    return await user_service.get_inactive_users(db)

@router.get(
    "/citoyens",
    response_model=list[UserResponse],
    summary="Comptes citoyens — identité des dossiers (admin)",
)
async def get_citoyens(
    status:       UserStatus | None = Query(None),
    db:           AsyncSession      = Depends(get_db),
    current_user: User              = Depends(require_admin),
):
    return await user_service.get_citoyens(db, status)


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(
    user_id:      UUID,
    db:           AsyncSession = Depends(get_db),
    current_user: User         = Depends(require_admin),
):
    return await user_service.get_user_by_id(user_id, db)


@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id:      UUID,
    data:         UserUpdate,
    db:           AsyncSession = Depends(get_db),
    current_user: User         = Depends(require_admin),
):
    return await user_service.update_user(user_id, data, current_user, db)


@router.delete("/{user_id}")
async def delete_user(
    user_id:      UUID,
    db:           AsyncSession = Depends(get_db),
    current_user: User         = Depends(require_admin),
):
    return await user_service.delete_user(user_id, current_user, db)