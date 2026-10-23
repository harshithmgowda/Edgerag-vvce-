"""Initialize EdgeRAG database tables and bootstrap administrator account."""
import sys
import os
import re

# Add services/api to python path
current_dir = os.path.dirname(os.path.abspath(__file__))
api_dir = os.path.abspath(os.path.join(current_dir, "..", "..", "services", "api"))
sys.path.insert(0, api_dir)

from app.config import settings

def ensure_mysql_database_exists():
    db_url = settings.DATABASE_URL
    if "mysql" in db_url.lower():
        print(f"[*] Checking MySQL database configuration ({db_url.split('@')[-1]})...")
        try:
            # Parse mysql url: mysql+pymysql://user:password@host:port/dbname
            match = re.search(r"://([^:]+):([^@]+)@([^:/]+)(?::(\d+))?/([^?]+)", db_url)
            if match:
                user, password, host, port, db_name = match.groups()
                port = int(port) if port else 3306

                import pymysql
                conn = pymysql.connect(
                    host=host,
                    user=user,
                    password=password,
                    port=port,
                    autocommit=True
                )
                with conn.cursor() as cursor:
                    cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{db_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
                conn.close()
                print(f"[+] Verified/Created MySQL database '{db_name}'.")
        except Exception as e:
            print(f"[!] Notice: Could not connect to MySQL server on {db_url}: {e}")
            print("[!] If MySQL service is not started, start it via Windows Services ('services.msc' -> 'MySQL80').")

def init_database():
    ensure_mysql_database_exists()

    from app.db.database import engine, Base, SessionLocal
    from app.db.models import UserModel
    from app.security.auth import get_password_hash

    print("[*] Creating all database tables...")
    try:
        Base.metadata.create_all(bind=engine)
        print("[+] Database tables successfully created/verified.")

        db = SessionLocal()
        try:
            admin = db.query(UserModel).filter(UserModel.username == "admin").first()
            if not admin:
                print("[*] Bootstrapping administrator account...")
                admin = UserModel(
                    username="admin",
                    email="admin@edgerag.internal",
                    hashed_password=get_password_hash("IndustrialAdmin2026!"),
                    role="ADMIN",
                )
                db.add(admin)
                db.commit()
                print("[+] Administrator bootstrapped: username='admin', password='IndustrialAdmin2026!'")
            else:
                print("[+] Administrator account already exists.")
        finally:
            db.close()
    except Exception as e:
        print(f"[-] Database initialization error: {e}")

if __name__ == "__main__":
    init_database()
