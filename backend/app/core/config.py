from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import model_validator


class Settings(BaseSettings):
    app_name: str = "Track Children API"
    database_url: str = (
        "postgresql://track_children:track_children_dev@localhost:5433/track_children"
    )
    dev_auth: bool = False
    auth_secret: str = ""
    sms_webhook_url: str = ""
    sms_webhook_token: str = ""
    auth_issuer: str = "track-children"
    auth_audience: str = "track-children-mobile"
    cors_origins: list[str] = []
    app_env: str = "production"
    auth_skip_otp: bool = False
    # ai-service (nhận xét AI cho video nhật ký); token dùng chung với INTERNAL_TOKEN bên đó
    ai_service_url: str = "http://localhost:8001"
    ai_service_token: str = ""
    ai_video_max_mb: int = 150
    # MinIO (S3) lưu ảnh / video nhật ký
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "track_children"
    minio_secret_key: str = "track_children_dev"
    minio_bucket: str = "diary-media"
    minio_secure: bool = False
    # Gốc URL mobile dùng để tải file (vd https://media.example.com). Trống: lấy
    # host mà mobile gọi backend + minio_public_port (emulator 10.0.2.2, máy thật IP LAN)
    minio_public_url: str = ""
    minio_public_port: int = 9000
    media_url_ttl_minutes: int = 60
    diary_image_max_mb: int = 15
    diary_video_max_mb: int = 150

    @model_validator(mode="after")
    def local_otp_only(self):
        if self.auth_skip_otp and self.app_env != "local":
            raise ValueError("AUTH_SKIP_OTP requires APP_ENV=local")
        return self

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
