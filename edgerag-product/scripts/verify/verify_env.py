"""Verify EdgeRAG environment prerequisites and services status."""
import sys
import os
import shutil

def verify():
    print("=" * 60)
    print(" 🚀 EdgeRAG Environment Diagnostics (No Docker)")
    print("=" * 60)

    # 1. Python check
    py_ver = sys.version.split()[0]
    print(f"[*] Python Runtime: {py_ver} (Path: {sys.executable})")

    # 2. Node.js check
    node_path = shutil.which("node")
    if node_path:
        print(f"[+] Node.js: Detected ({node_path})")
    else:
        print("[-] Node.js: Not found in current PATH. Download from https://nodejs.org")

    # 3. Flutter check
    flutter_path = shutil.which("flutter")
    if flutter_path:
        print(f"[+] Flutter: Detected ({flutter_path})")
    else:
        print("[-] Flutter: Not found in current PATH. Download from https://flutter.dev")

    # 4. Check services/api requirements
    current_dir = os.path.dirname(os.path.abspath(__file__))
    api_dir = os.path.abspath(os.path.join(current_dir, "..", "..", "services", "api"))
    sys.path.insert(0, api_dir)

    try:
        from app.config import settings
        from app.db.database import engine
        from sqlalchemy import text
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print(f"[+] Database: Connected ({settings.DATABASE_URL})")
    except Exception as e:
        print(f"[-] Database Error: {e}")

    try:
        import redis
        from app.config import settings
        r = redis.from_url(settings.REDIS_URL, socket_connect_timeout=1)
        r.ping()
        print(f"[+] Redis Broker: Connected ({settings.REDIS_URL})")
    except Exception:
        print(f"[!] Redis: Not running on {settings.REDIS_URL}. (Sync fallback active)")

    print("=" * 60)
    print(" Diagnostics completed.")

if __name__ == "__main__":
    verify()
