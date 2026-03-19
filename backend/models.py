from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import Boolean, DateTime, ForeignKey, JSON, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from backend.db import Base


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


json_payload_type = JSON().with_variant(JSONB, "postgresql")


class Account(Base):
    __tablename__ = "accounts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    account_id: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(128))
    provider_name: Mapped[str] = mapped_column(String(128))
    account_hint: Mapped[str | None] = mapped_column(String(255), nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    access_token: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    current_user_id: Mapped[str] = mapped_column(String(128))
    partner_user_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
    )

    member_spaces: Mapped[list["SpaceMember"]] = relationship(back_populates="account")
    created_spaces: Mapped[list["Space"]] = relationship(back_populates="created_by_account")
    updated_snapshots: Mapped[list["SpaceSnapshot"]] = relationship(back_populates="updated_by_account")


class Space(Base):
    __tablename__ = "spaces"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    space_id: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    title: Mapped[str] = mapped_column(String(255))
    invite_code: Mapped[str | None] = mapped_column(String(64), unique=True, nullable=True, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_by_account_id: Mapped[str | None] = mapped_column(
        ForeignKey("accounts.account_id"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
    )

    created_by_account: Mapped[Account | None] = relationship(
        back_populates="created_spaces",
        foreign_keys=[created_by_account_id],
    )
    members: Mapped[list["SpaceMember"]] = relationship(
        back_populates="space",
        cascade="all, delete-orphan",
    )
    snapshot: Mapped["SpaceSnapshot | None"] = relationship(
        back_populates="space",
        cascade="all, delete-orphan",
        uselist=False,
    )


class SpaceMember(Base):
    __tablename__ = "space_members"
    __table_args__ = (UniqueConstraint("space_id", "account_id", name="uq_space_member"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    space_id: Mapped[str] = mapped_column(ForeignKey("spaces.space_id", ondelete="CASCADE"), index=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.account_id", ondelete="CASCADE"), index=True)
    role: Mapped[str] = mapped_column(String(32))
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)

    space: Mapped[Space] = relationship(back_populates="members")
    account: Mapped[Account] = relationship(back_populates="member_spaces")


class SpaceSnapshot(Base):
    __tablename__ = "space_snapshots"
    __table_args__ = (UniqueConstraint("space_id", name="uq_space_snapshot_space"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    snapshot_id: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    space_id: Mapped[str] = mapped_column(ForeignKey("spaces.space_id", ondelete="CASCADE"), index=True)
    payload_json: Mapped[dict[str, Any]] = mapped_column(json_payload_type)
    updated_by_account_id: Mapped[str | None] = mapped_column(
        ForeignKey("accounts.account_id"),
        nullable=True,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
    )

    space: Mapped[Space] = relationship(back_populates="snapshot")
    updated_by_account: Mapped[Account | None] = relationship(
        back_populates="updated_snapshots",
        foreign_keys=[updated_by_account_id],
    )


class MemoryAsset(Base):
    __tablename__ = "memory_assets"
    __table_args__ = (UniqueConstraint("asset_id", name="uq_memory_asset_asset_id"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    asset_id: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    memory_id: Mapped[str] = mapped_column(String(128), index=True)
    space_id: Mapped[str] = mapped_column(ForeignKey("spaces.space_id", ondelete="CASCADE"), index=True)
    storage_key: Mapped[str] = mapped_column(String(512), unique=True)
    mime_type: Mapped[str] = mapped_column(String(128))
    byte_size: Mapped[int] = mapped_column()
    checksum: Mapped[str | None] = mapped_column(String(128), nullable=True)
    width: Mapped[int | None] = mapped_column(nullable=True)
    height: Mapped[int | None] = mapped_column(nullable=True)
    uploaded_by_account_id: Mapped[str | None] = mapped_column(
        ForeignKey("accounts.account_id"),
        nullable=True,
    )
    uploaded_by_user_id: Mapped[str] = mapped_column(String(128))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
