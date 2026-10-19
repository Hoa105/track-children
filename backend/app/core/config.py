from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Track Children API"
    database_url: str = "postgresql://track_children:track_children_dev@localhost:5433/track_children"
    # Tạm thay cho đăng nhập thật (xem app/core/security.py). Production phải để False.
    dev_auth: bool = False
    cors_origins: list[str] = ["http://localhost:5173"]

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
