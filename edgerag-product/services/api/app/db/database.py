import logging
from sqlalchemy import create_engine, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.config import settings

logger = logging.getLogger("edgerag.db")

connect_args = {}
if settings.DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

try:
    if settings.DATABASE_URL.startswith("mysql"):
        # Auto-create database if it doesn't exist yet on MySQL
        from urllib.parse import urlparse
        parsed = urlparse(settings.DATABASE_URL)
        db_name = parsed.path.lstrip("/")
        if db_name:
            server_url = f"{parsed.scheme}://{parsed.netloc}/"
            server_engine = create_engine(server_url, pool_pre_ping=True)
            with server_engine.connect() as s_conn:
                s_conn.execute(text(f"CREATE DATABASE IF NOT EXISTS `{db_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"))
                s_conn.commit()
            server_engine.dispose()

    engine = create_engine(
        settings.DATABASE_URL,
        connect_args=connect_args,
        pool_pre_ping=True,
        echo=False
    )
    # Quick probe
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    print(f"[*] Successfully connected to database: {settings.DATABASE_URL.split('@')[-1] if '@' in settings.DATABASE_URL else settings.DATABASE_URL}")
except Exception as e:
    # If MySQL is not running or unreachable, gracefully fallback to SQLite
    print(f"\n[!] Notice: MySQL connection failed ({e}).")
    print("[*] Automatically engaging SQLite development database (./edgerag_dev.db) so your backend starts cleanly...\n")
    
    sqlite_url = "sqlite:///./edgerag_dev.db"
    engine = create_engine(
        sqlite_url,
        connect_args={"check_same_thread": False},
        pool_pre_ping=True,
        echo=False
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
