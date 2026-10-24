from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import UserModel
from app.schemas.schemas import LoginRequest, TokenResponse, UserCreate, UserResponse
from app.security.auth import verify_password, get_password_hash, create_access_token, get_current_user

router = APIRouter()

@router.post("/auth/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(UserModel).filter(UserModel.username == request.username).first()
    if not user or not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    token = create_access_token({"sub": user.username, "role": user.role})
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=UserResponse.model_validate(user),
    )

@router.post("/auth/register-admin", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register_admin(user_in: UserCreate, db: Session = Depends(get_db)):
    # Verify no admin already exists
    existing = db.query(UserModel).filter(UserModel.role == "ADMIN").first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Administrator account is already registered",
        )

    new_user = UserModel(
        username=user_in.username,
        email=user_in.email,
        hashed_password=get_password_hash(user_in.password),
        role="ADMIN",
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return UserResponse.model_validate(new_user)

@router.get("/auth/me", response_model=UserResponse)
def get_me(current_user: UserModel = Depends(get_current_user)):
    return UserResponse.model_validate(current_user)
