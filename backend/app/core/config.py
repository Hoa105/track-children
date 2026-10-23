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

    @model_validator(mode="after")
    def local_otp_only(self):
        if self.auth_skip_otp and self.app_env != "local":
            raise ValueError("AUTH_SKIP_OTP requires APP_ENV=local")
        return self

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
