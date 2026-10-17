from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Track Children API"
    database_url: str = "postgresql://track_children:track_children_dev@localhost:5433/track_children"
    auth_secret: str = ""
    sms_webhook_url: str = ""
    sms_webhook_token: str = ""
    auth_issuer: str = "track-children"
    auth_audience: str = "track-children-mobile"
    cors_origins: list[str] = []

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
