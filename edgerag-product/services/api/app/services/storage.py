import os
import shutil
from typing import BinaryIO, Optional
try:
    from minio import Minio
    from minio.error import S3Error
except ImportError:
    Minio = None
    class S3Error(Exception):
        pass
from app.config import settings

class StorageService:
    def __init__(self):
        self._minio_client: Optional[Minio] = None
        self._use_local_fallback = False

        # Attempt MinIO initialization
        try:
            self._minio_client = Minio(
                endpoint=settings.MINIO_ENDPOINT,
                access_key=settings.MINIO_ACCESS_KEY,
                secret_key=settings.MINIO_SECRET_KEY,
                secure=settings.MINIO_SECURE,
            )
            # Verify connectivity
            self._minio_client.list_buckets()
            self._ensure_buckets()
        except Exception:
            # Fall back to local filesystem storage
            self._use_local_fallback = True
            self._ensure_local_dirs()

    def _ensure_buckets(self):
        if not self._minio_client:
            return
        for bucket in [settings.MINIO_BUCKET_MANUALS, settings.MINIO_BUCKET_PACKAGES]:
            if not self._minio_client.bucket_exists(bucket):
                self._minio_client.make_bucket(bucket)

    def _ensure_local_dirs(self):
        os.makedirs(os.path.join(settings.LOCAL_STORAGE_DIR, "manuals"), exist_ok=True)
        os.makedirs(os.path.join(settings.LOCAL_STORAGE_DIR, "packages"), exist_ok=True)

    def upload_file(self, bucket: str, object_name: str, file_data: BinaryIO, length: int, content_type: str = "application/octet-stream") -> str:
        if not self._use_local_fallback and self._minio_client:
            try:
                self._minio_client.put_object(
                    bucket_name=bucket,
                    object_name=object_name,
                    data=file_data,
                    length=length,
                    content_type=content_type,
                )
                return f"{bucket}/{object_name}"
            except Exception:
                self._use_local_fallback = True

        # Local storage fallback
        sub_dir = "manuals" if "manual" in bucket else "packages"
        local_path = os.path.join(settings.LOCAL_STORAGE_DIR, sub_dir, object_name)
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        file_data.seek(0)
        with open(local_path, "wb") as f:
            shutil.copyfileobj(file_data, f)
        return local_path

    def get_file_path_or_bytes(self, storage_path: str) -> str:
        # Returns absolute local path if accessible
        if os.path.exists(storage_path):
            return os.path.abspath(storage_path)

        # Check in local storage directory
        for sub_dir in ["manuals", "packages"]:
            candidate = os.path.join(settings.LOCAL_STORAGE_DIR, sub_dir, os.path.basename(storage_path))
            if os.path.exists(candidate):
                return os.path.abspath(candidate)

        return storage_path

storage_service = StorageService()
