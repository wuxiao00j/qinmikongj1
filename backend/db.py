from __future__ import annotations

from collections.abc import Generator
from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from backend.config import settings


class Base(DeclarativeBase):
    pass


SessionLocal = sessionmaker(
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
    class_=Session,
)


@lru_cache
def get_engine():
    return create_engine(
        settings.database_url,
        echo=settings.database_echo,
        future=True,
    )


def get_db() -> Generator[Session, None, None]:
    session = SessionLocal(bind=get_engine())
    try:
        yield session
    finally:
        session.close()
