# user_service/app/routers/user_router.py

from uuid import UUID
from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import require_admin
from app.db.database import get_db
from app.models.user import User
from app.schemas.user import UserActivate, UserCreate, UserResponse, UserUpdate
from app.services import user_service

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
    data: UserActivate,
    db:   AsyncSession = Depends(get_db),
):
    return await user_service.activate_account(data.token, data.password, db)


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