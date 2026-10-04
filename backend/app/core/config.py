from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Track Children API"
    database_url: str = "sqlite:///./track_children.db"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
