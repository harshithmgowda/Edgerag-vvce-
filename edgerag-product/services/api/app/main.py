from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.db.database import engine, Base, SessionLocal
from app.db.models import UserModel
from app.security.auth import get_password_hash
from app.api.v1.router import api_router
from app.services.storage import storage_service

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Ensure tables are created
    Base.metadata.create_all(bind=engine)

    # Bootstrap default administrator account if database is freshly initialized
    db = SessionLocal()
    try:
        admin_user = db.query(UserModel).filter(UserModel.username == "admin").first()
        if not admin_user:
            admin_user = UserModel(
                username="admin",
                email="admin@edgerag.internal",
                hashed_password=get_password_hash("IndustrialAdmin2026!"),
                role="ADMIN",
            )
            db.add(admin_user)
            db.commit()
    finally:
        db.close()

    yield

app = FastAPI(
    title="EdgeRAG Headquarters & Sync API",
    version="1.0.0",
    description="Offline + Online Agentic RAG Platform for Industrial Field Engineers",
    lifespan=lifespan,
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permits localhost:3000 and Android 192.168.137.x mobile clients
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount /api/v1 router
app.include_router(api_router)

@app.get("/")
def root():
    return {
        "product": "EdgeRAG Headquarters API",
        "version": "1.0.0",
        "docs_url": "/docs",
        "openapi_url": "/openapi.json"
    }
