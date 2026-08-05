from functools import lru_cache
from socket import gethostname

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="SRE_DEMO_", extra="ignore")

    app_name: str = "Northstar Supply API"
    environment: str = "local"
    service_version: str = "0.1.0"
    git_sha: str = "development"
    image_digest: str = "local"
    instance_id: str = gethostname()
    trace_console_exporter: bool = False
    allowed_origins: tuple[str, ...] = (
        "http://127.0.0.1:5173",
        "http://localhost:5173",
    )

    @field_validator("allowed_origins", mode="before")
    @classmethod
    def split_origins(cls, value: object) -> object:
        if isinstance(value, str):
            return tuple(origin.strip() for origin in value.split(",") if origin.strip())
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
