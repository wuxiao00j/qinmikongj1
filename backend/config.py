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
    email_otp_secret: str = os.getenv("EMAIL_OTP_SECRET", "dev-email-otp-secret-change-me")
    email_otp_ttl_seconds: int = int(os.getenv("EMAIL_OTP_TTL_SECONDS", "600"))
    email_otp_cooldown_seconds: int = int(os.getenv("EMAIL_OTP_COOLDOWN_SECONDS", "60"))
    email_otp_max_attempts: int = int(os.getenv("EMAIL_OTP_MAX_ATTEMPTS", "5"))
    # 开发环境可固定验证码，生产环境不要设置该值。
    email_otp_fixed_code: str | None = os.getenv("EMAIL_OTP_FIXED_CODE")
    # 开发联调用：允许把明文验证码写到日志里；生产环境应关闭。
    email_otp_log_plaintext_code: bool = _env_flag("EMAIL_OTP_LOG_PLAINTEXT_CODE", default=True)
    memory_asset_storage_dir: str = os.getenv(
        "MEMORY_ASSET_STORAGE_DIR",
        os.path.join(os.path.dirname(__file__), "storage", "memory_assets"),
    )
    memory_asset_max_bytes: int = int(os.getenv("MEMORY_ASSET_MAX_BYTES", "12582912"))

    smtp_host: str = os.getenv("SMTP_HOST", "smtp.qq.com")
    smtp_port: int = int(os.getenv("SMTP_PORT", "587"))
    smtp_user: str = os.getenv("SMTP_USER", "")
    smtp_password: str = os.getenv("SMTP_PASSWORD", "")  # QQ 邮箱授权码
    smtp_from: str = os.getenv("SMTP_FROM", "余白 <noreply@yuba.space>")


settings = Settings()
