from __future__ import annotations

import os
from dataclasses import dataclass


def _env_flag(name: str, default: bool = False) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg://couplespace:couplespace@127.0.0.1:5433/couplespace",
    )
    database_echo: bool = _env_flag("DATABASE_ECHO", default=False)
    seed_on_startup: bool = _env_flag("SEED_ON_STARTUP", default=True)


settings = Settings()
