from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "AI Account Book"
    database_url: str = "sqlite:///./ai_account_book.db"
    secret_key: str = "change-this-secret"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7
    cors_origins: str = "*"
    ai_provider: str = "local"
    openai_api_key: str | None = None
    openai_base_url: str = "https://api.openai.com/v1"
    openai_audio_model: str = "gpt-4o-mini-transcribe"
    deepseek_api_key: str | None = None
    deepseek_base_url: str = "https://api.deepseek.com"
    deepseek_model: str = "deepseek-v4-flash"
    voice_upload_dir: str = "uploads/voice"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @property
    def cors_origin_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
