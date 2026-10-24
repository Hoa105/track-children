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
    auth_otp_preview: bool = False
    google_client_ids: list[str] = []
    apple_client_ids: list[str] = []
    apple_team_id: str = ""
    apple_key_id: str = ""
    apple_private_key_path: str = ""
    apple_redirect_uri: str = ""
    apple_android_package: str = ""

    @model_validator(mode="after")
    def local_otp_only(self):
        if self.auth_skip_otp and self.app_env != "local":
            raise ValueError("AUTH_SKIP_OTP requires APP_ENV=local")
        if self.auth_otp_preview and self.app_env != "local":
            raise ValueError("AUTH_OTP_PREVIEW requires APP_ENV=local")
        return self

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
