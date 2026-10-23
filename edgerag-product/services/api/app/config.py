import os
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # Host & Server
    EDGERAG_HOST: str = "0.0.0.0"
    EDGERAG_PORT: int = 8000
    EDGERAG_CORS_ORIGINS: str = "http://localhost:3000,http://127.0.0.1:3000,http://192.168.137.1:3000"

    # Security & Tokens
    EDGERAG_SECRET_KEY: str = "edgerag_production_secret_key_89234892374982374982374982374"
    EDGERAG_JWT_ALGORITHM: str = "HS256"
    EDGERAG_ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    # MySQL / SQLite Database
    # Default is SQLite for instant zero-dependency execution; can switch to MySQL via DATABASE_URL
    DATABASE_URL: str = "sqlite:///./edgerag_dev.db"

    # Redis & Celery
    REDIS_URL: str = "redis://127.0.0.1:6379/0"
    CELERY_BROKER_URL: str = "redis://127.0.0.1:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://127.0.0.1:6379/1"

    # MinIO / Object Storage
    MINIO_ENDPOINT: str = "127.0.0.1:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin"
    MINIO_SECURE: bool = False
    MINIO_BUCKET_MANUALS: str = "edgerag-manuals"
    MINIO_BUCKET_PACKAGES: str = "edgerag-packages"
    LOCAL_STORAGE_DIR: str = "./storage"

    # AI & RAG Specs
    EMBEDDING_MODEL_NAME: str = "all-MiniLM-L6-v2"
    EMBEDDING_DIMENSION: int = 384
    MAX_CHUNK_TOKENS: int = 224
    CHUNK_OVERLAP_TOKENS: int = 32

    # Cloud AI Providers
    GEMINI_API_KEY: str = ""
    GEMINI_DEFAULT_MODEL: str = "gemini-1.5-flash"
    OPENAI_API_KEY: str = ""
    ANTHROPIC_API_KEY: str = ""
    GROQ_API_KEY: str = ""
    NVIDIA_NIM_API_KEY: str = "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"
    NVIDIA_NIM_MODEL: str = "meta/llama-3.2-11b-vision-instruct"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @property
    def cors_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.EDGERAG_CORS_ORIGINS.split(",") if origin.strip()]

settings = Settings()
