from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import model_validator, Field
from typing import Literal
from pathlib import Path


class Settings(BaseSettings):
    app_name: str = "Track Children API"
    database_url: str = (
        "postgresql://track_children:track_children_dev@localhost:5433/track_children"
    )
    dev_auth: bool = False
    auth_secret: str = ""
    sms_webhook_url: str = ""
    sms_webhook_token: str = ""
    email_webhook_url: str = ""
    email_webhook_token: str = ""
    email_provider: str = "webhook"
    brevo_api_key: str = ""
    brevo_sender_email: str = ""
    brevo_sender_name: str = "Track Children"
    smtp2go_api_key: str = ""
    smtp2go_sender_email: str = ""
    smtp2go_sender_name: str = "Track Children"
    legal_documents_path: str = ""
    auth_issuer: str = "track-children"
    auth_audience: str = "track-children-mobile"
    auth_admin_audience: str = "track-children-admin"
    cors_origins: list[str] = []
    app_env: str = "production"
    auth_skip_otp: bool = False
    auth_rate_limit_path: str = ""
    auth_rate_limit_backend: Literal['sqlite','postgres'] = 'sqlite'
    auth_otp_preview: bool = False
    auth_v2_enabled: bool = False
    auth_simulation: bool = False
    auth_security_webhook_url: str = ""
    auth_security_webhook_token: str = ""
    auth_worker_interval_seconds: int = Field(default=30, ge=5, le=60)
    auth_password_blocklist_path: str = str(Path(__file__).resolve().parents[2]/'data'/'auth'/'common-passwords.txt')
    auth_otp_secret: str = ""
    auth_otp_target_limit: int = Field(default=5,ge=1,le=100)
    auth_otp_ip_limit: int = Field(default=20,ge=1,le=10000)
    auth_otp_global_limit: int = Field(default=100,ge=1,le=1000000)
    auth_recovery_inactive_days: int = Field(default=90,ge=1,le=3650)
    auth_recovery_failure_limit: int = Field(default=5,ge=1,le=100)
    auth_recovery_failure_minutes: int = Field(default=30,ge=1,le=60)
    auth_recovery_security_hours: int = Field(default=24,ge=1,le=720)
    google_client_ids: list[str] = []
    apple_client_ids: list[str] = []
    apple_team_id: str = ""
    apple_key_id: str = ""
    apple_private_key_path: str = ""
    apple_redirect_uri: str = ""
    apple_android_package: str = ""
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
        if self.auth_simulation:
            from psycopg.conninfo import conninfo_to_dict
            if self.app_env!='local' or not conninfo_to_dict(self.database_url).get('dbname','').endswith('_test'):
                raise ValueError('AUTH_SIMULATION requires APP_ENV=local and a dedicated *_test database')
        if self.auth_skip_otp and self.app_env != "local":
            raise ValueError("AUTH_SKIP_OTP requires APP_ENV=local")
        if self.auth_otp_preview and self.app_env != "local":
            raise ValueError("AUTH_OTP_PREVIEW requires APP_ENV=local")
        return self

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
