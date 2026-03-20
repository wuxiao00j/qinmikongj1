from __future__ import annotations

import hashlib
import json
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import Depends, FastAPI, Header, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field, ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload
from starlette.requests import ClientDisconnect

from backend.auth import verify_password
from backend.config import settings
from backend.db import Base, SessionLocal, get_db, get_engine
from backend.models import Account, MemoryAsset, Space, SpaceMember, SpaceSnapshot
from backend.seed import seed_database


logger = logging.getLogger("backend.snapshot")


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(bind=get_engine())
    if settings.seed_on_startup:
        with SessionLocal(bind=get_engine()) as session:
            seed_database(session)
    yield


app = FastAPI(
    title="Couple Space MVP Backend",
    version="0.3.0",
    description="最小 PostgreSQL 骨架，当前支撑 login / demo-login / snapshot pull / snapshot push。",
    lifespan=lifespan,
)


class APIError(Exception):
    def __init__(self, status_code: int, code: str, message: str, detail: Any | None = None) -> None:
        self.status_code = status_code
        self.code = code
        self.message = message
        self.detail = detail
        super().__init__(message)


class DemoLoginRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    accountId: str | None = None
    displayName: str | None = None


class AuthenticatedAccountResponse(BaseModel):
    accountId: str
    displayName: str
    providerName: str
    accountHint: str | None = None
    accessToken: str


class LoginRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    email: str
    password: str


class CreateSpaceRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    title: str | None = None


class JoinSpaceRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    inviteCode: str


class SpaceConnectionResponse(BaseModel):
    spaceId: str
    title: str
    inviteCode: str
    isActivated: bool
    memberCount: int
    currentRole: str
    relationStatus: str
    currentAccountId: str
    currentUserId: str
    partnerAccountId: str | None = None
    partnerUserId: str | None = None


class SpaceParticipantSummary(BaseModel):
    accountId: str
    displayName: str
    providerName: str
    accountHint: str | None = None
    currentUserId: str
    role: str


class SpaceStatusResponse(BaseModel):
    spaceId: str
    title: str
    inviteCode: str
    isActivated: bool
    memberCount: int
    currentRole: str
    relationStatus: str
    currentAccountId: str
    currentUserId: str
    partnerAccountId: str | None = None
    partnerUserId: str | None = None
    currentAccount: SpaceParticipantSummary
    partner: SpaceParticipantSummary | None = None


class MemoryAssetUploadResponse(BaseModel):
    assetId: str
    memoryId: str
    spaceId: str
    storageKey: str
    mimeType: str
    byteSize: int
    checksum: str | None = None
    width: int | None = None
    height: int | None = None
    createdAt: datetime
    uploadedByUserId: str


class StoredRemoteMemoryModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    title: str
    detail: str
    date: datetime
    categoryRawValue: str
    imageLabel: str
    mood: str
    location: str
    weather: str
    isFeatured: bool
    spaceId: str
    createdByUserId: str
    createdAt: datetime
    updatedAt: datetime
    syncStatusRawValue: str


class StoredRemoteMemoryTombstoneModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    spaceId: str
    deletedByUserId: str
    deletedAt: datetime


class StoredRemoteWishModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    title: str
    titleUpdatedAt: datetime | None = None
    detail: str
    detailUpdatedAt: datetime | None = None
    note: str
    noteUpdatedAt: datetime | None = None
    categoryRawValue: str
    categoryUpdatedAt: datetime | None = None
    statusRawValue: str
    statusUpdatedAt: datetime | None = None
    targetText: str
    targetTextUpdatedAt: datetime | None = None
    symbol: str
    spaceId: str
    createdByUserId: str
    createdAt: datetime
    updatedAt: datetime
    updatedAtTimestamp: float | None = None
    syncStatusRawValue: str


class StoredRemoteWishTombstoneModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    spaceId: str
    deletedByUserId: str
    deletedAt: datetime


class StoredRemoteAnniversaryModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    title: str
    date: datetime
    categoryRawValue: str
    note: str
    cadenceRawValue: str
    spaceId: str
    createdByUserId: str
    createdAt: datetime
    updatedAt: datetime
    syncStatusRawValue: str


class StoredRemoteWeeklyTodoModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    title: str
    isCompleted: bool
    scheduledDate: datetime | None = None
    ownerRawValue: str | None = None
    spaceId: str
    createdByUserId: str
    createdAt: datetime
    updatedAt: datetime
    syncStatusRawValue: str


class StoredRemoteCurrentStatusModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    userId: str
    displayText: str
    toneRawValue: str
    effectiveScopeRawValue: str
    spaceId: str
    updatedAt: datetime


class StoredRemoteTonightDinnerModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    title: str
    note: str
    statusRawValue: str
    createdAt: datetime
    decidedAt: datetime | None = None
    createdByUserId: str
    spaceId: str
    syncStatusRawValue: str


class StoredRemoteRitualModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    title: str
    kindRawValue: str
    isCompleted: bool
    note: str
    createdAt: datetime
    updatedAt: datetime
    createdByUserId: str
    spaceId: str
    syncStatusRawValue: str


class StoredRemoteWhisperNoteModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    id: str
    content: str
    createdAt: datetime
    createdByUserId: str
    spaceId: str
    syncStatusRawValue: str


class StoredScopeModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    currentUserId: str
    partnerUserId: str | None = None
    spaceId: str
    isSharedSpace: bool


class StoredSnapshotRequestModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    scope: StoredScopeModel
    memories: list[StoredRemoteMemoryModel] = Field(default_factory=list)
    memoryTombstones: list[StoredRemoteMemoryTombstoneModel] = Field(default_factory=list)
    wishes: list[StoredRemoteWishModel] = Field(default_factory=list)
    wishTombstones: list[StoredRemoteWishTombstoneModel] = Field(default_factory=list)
    anniversaries: list[StoredRemoteAnniversaryModel] = Field(default_factory=list)
    weeklyTodos: list[StoredRemoteWeeklyTodoModel] = Field(default_factory=list)
    tonightDinners: list[StoredRemoteTonightDinnerModel] = Field(default_factory=list)
    rituals: list[StoredRemoteRitualModel] = Field(default_factory=list)
    currentStatuses: list[StoredRemoteCurrentStatusModel] = Field(default_factory=list)
    whisperNotes: list[StoredRemoteWhisperNoteModel] = Field(default_factory=list)
    relationStatusRawValue: str
    updatedAt: datetime


class RemoteSnapshotResponseModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    snapshotId: str
    spaceId: str
    currentUserId: str
    partnerUserId: str | None = None
    isSharedSpace: bool
    memories: list[StoredRemoteMemoryModel] = Field(default_factory=list)
    memoryTombstones: list[StoredRemoteMemoryTombstoneModel] = Field(default_factory=list)
    wishes: list[StoredRemoteWishModel] = Field(default_factory=list)
    wishTombstones: list[StoredRemoteWishTombstoneModel] = Field(default_factory=list)
    anniversaries: list[StoredRemoteAnniversaryModel] = Field(default_factory=list)
    weeklyTodos: list[StoredRemoteWeeklyTodoModel] = Field(default_factory=list)
    tonightDinners: list[StoredRemoteTonightDinnerModel] = Field(default_factory=list)
    rituals: list[StoredRemoteRitualModel] = Field(default_factory=list)
    currentStatuses: list[StoredRemoteCurrentStatusModel] = Field(default_factory=list)
    whisperNotes: list[StoredRemoteWhisperNoteModel] = Field(default_factory=list)
    relationStatus: str
    updatedAt: datetime


class SnapshotRecordModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    snapshotId: str
    memories: list[StoredRemoteMemoryModel] = Field(default_factory=list)
    memoryTombstones: list[StoredRemoteMemoryTombstoneModel] = Field(default_factory=list)
    wishes: list[StoredRemoteWishModel] = Field(default_factory=list)
    wishTombstones: list[StoredRemoteWishTombstoneModel] = Field(default_factory=list)
    anniversaries: list[StoredRemoteAnniversaryModel] = Field(default_factory=list)
    weeklyTodos: list[StoredRemoteWeeklyTodoModel] = Field(default_factory=list)
    tonightDinners: list[StoredRemoteTonightDinnerModel] = Field(default_factory=list)
    rituals: list[StoredRemoteRitualModel] = Field(default_factory=list)
    currentStatuses: list[StoredRemoteCurrentStatusModel] = Field(default_factory=list)
    whisperNotes: list[StoredRemoteWhisperNoteModel] = Field(default_factory=list)
    relationStatus: str
    updatedAt: datetime
    lastUpdatedByAccountId: str | None = None


@app.exception_handler(APIError)
async def api_error_handler(_: Request, exc: APIError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": exc.code,
                "message": exc.message,
                "detail": exc.detail,
            }
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_error_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": {
                "code": "invalid_request",
                "message": "请求参数或 JSON payload 不合法。",
                "detail": exc.errors(),
            }
        },
    )


@app.exception_handler(Exception)
async def internal_error_handler(_: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": {
                "code": "internal_error",
                "message": "服务端内部错误。",
                "detail": str(exc),
            }
        },
    )


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def bearer_token_from_header(authorization: str | None) -> str:
    if authorization is None or authorization.startswith("Bearer ") is False:
        raise APIError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="unauthorized",
            message="缺少有效的 Bearer token。",
        )
    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise APIError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="unauthorized",
            message="Bearer token 不能为空。",
        )
    return token


def find_account_by_login_hint(session: Session, payload: DemoLoginRequest | None) -> Account:
    default_account = session.scalar(select(Account).order_by(Account.account_id.asc()))
    if default_account is None:
        raise APIError(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            code="seed_missing",
            message="服务端没有可用的测试账号 seed。",
        )

    if payload is None:
        return default_account

    if payload.accountId:
        account = session.scalar(select(Account).where(Account.account_id == payload.accountId))
        if account is not None:
            return account

    if payload.displayName:
        normalized_name = payload.displayName.strip().lower()
        account = session.scalar(select(Account).where(Account.display_name.ilike(normalized_name)))
        if account is not None:
            return account

    raise APIError(
        status_code=status.HTTP_404_NOT_FOUND,
        code="account_not_found",
        message="没有找到对应的测试账号。",
    )


def build_authenticated_account_response(account: Account) -> AuthenticatedAccountResponse:
    return AuthenticatedAccountResponse(
        accountId=account.account_id,
        displayName=account.display_name,
        providerName=account.provider_name,
        accountHint=account.account_hint,
        accessToken=account.access_token,
    )


def authenticate_account(session: Session, payload: LoginRequest) -> Account:
    normalized_email = payload.email.strip().lower()
    if not normalized_email or not payload.password:
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="invalid_login_request",
            message="email 和 password 不能为空。",
        )

    account = session.scalar(
        select(Account).where(
            Account.account_hint.is_not(None),
            Account.account_hint.ilike(normalized_email),
        )
    )
    if account is None or not verify_password(payload.password, account.password_hash):
        raise APIError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="invalid_credentials",
            message="邮箱或密码不正确。",
        )

    return account


def require_account(
    session: Session,
    authorization: str | None,
    account_id_header: str | None,
    session_account_id_header: str | None,
) -> Account:
    token = bearer_token_from_header(authorization)
    account = session.scalar(select(Account).where(Account.access_token == token))

    if account is None:
        raise APIError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="unauthorized",
            message="Bearer token 无效或已失效。",
        )

    if account_id_header and account_id_header != account.account_id:
        raise APIError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="account_mismatch",
            message="请求头中的 accountId 与 token 不一致。",
        )

    if session_account_id_header and session_account_id_header != account.account_id:
        raise APIError(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="session_account_mismatch",
            message="会话 accountId 与 token 不一致。",
        )

    return account


def get_space_or_raise(session: Session, space_id: str) -> Space:
    space = session.scalar(
        select(Space)
        .options(selectinload(Space.members), selectinload(Space.snapshot))
        .where(Space.space_id == space_id)
    )
    if space is None:
        raise APIError(
            status_code=status.HTTP_404_NOT_FOUND,
            code="space_not_found",
            message=f"spaceId `{space_id}` 不存在。",
        )
    return space


def ensure_space_access(session: Session, space_id: str, account: Account) -> Space:
    space = get_space_or_raise(session, space_id)
    if any(member.account_id == account.account_id for member in space.members):
        return space
    raise APIError(
        status_code=status.HTTP_403_FORBIDDEN,
        code="space_forbidden",
        message="当前账号无权访问这个空间。",
    )


def resolve_partner_user_id(session: Session, space: Space, account: Account) -> str | None:
    for member in space.members:
        if member.account_id == account.account_id:
            continue
        partner_account = session.scalar(select(Account).where(Account.account_id == member.account_id))
        if partner_account is not None:
            return partner_account.current_user_id
    return account.partner_user_id


def resolve_memory_asset_extension(mime_type: str) -> str:
    normalized = mime_type.strip().lower()
    mapping = {
        "image/jpeg": ".jpg",
        "image/jpg": ".jpg",
        "image/png": ".png",
        "image/heic": ".heic",
        "image/heif": ".heif",
        "image/webp": ".webp",
    }
    extension = mapping.get(normalized)
    if extension is None:
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="unsupported_mime_type",
            message="当前只支持常见图片格式上传。",
            detail={"mimeType": mime_type},
        )
    return extension


def memory_asset_storage_root() -> Path:
    root = Path(settings.memory_asset_storage_dir).expanduser()
    root.mkdir(parents=True, exist_ok=True)
    return root


def build_memory_asset_storage_key(space_id: str, asset_id: str, extension: str) -> str:
    return f"spaces/{space_id}/memory-assets/{asset_id}{extension}"


def write_memory_asset_file(storage_key: str, body: bytes) -> Path:
    destination = memory_asset_storage_root() / storage_key
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(body)
    return destination


def memory_asset_file_path(storage_key: str) -> Path:
    destination = memory_asset_storage_root() / storage_key
    destination.parent.mkdir(parents=True, exist_ok=True)
    return destination


async def stream_memory_asset_file(
    request: Request,
    destination: Path,
    *,
    max_bytes: int,
    space_id: str,
    memory_id: str,
) -> tuple[int, str]:
    temp_destination = destination.with_suffix(f"{destination.suffix}.part")
    if temp_destination.exists():
        temp_destination.unlink()

    received_bytes = 0
    checksum = hashlib.sha256()

    try:
        with temp_destination.open("wb") as handle:
            async for chunk in request.stream():
                if not chunk:
                    continue

                received_bytes += len(chunk)
                if received_bytes > max_bytes:
                    raise APIError(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        code="memory_asset_too_large",
                        message="图片暂时超过当前测试环境允许的大小。",
                        detail={"maxBytes": max_bytes, "receivedBytes": received_bytes},
                    )

                checksum.update(chunk)
                handle.write(chunk)

            handle.flush()
    except ClientDisconnect as error:
        temp_destination.unlink(missing_ok=True)
        logger.warning(
            "memory asset upload disconnected space=%s memory=%s received_bytes=%s error=%s",
            space_id,
            memory_id,
            received_bytes,
            error.__class__.__name__,
        )
        raise APIError(
            status_code=status.HTTP_400_BAD_REQUEST,
            code="client_disconnected",
            message="图片上传在传输过程中中断，请稍后重试。",
            detail={"receivedBytes": received_bytes},
        ) from error
    except Exception:
        temp_destination.unlink(missing_ok=True)
        raise

    if received_bytes == 0:
        temp_destination.unlink(missing_ok=True)
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="empty_upload_body",
            message="图片上传内容不能为空。",
        )

    temp_destination.replace(destination)
    return received_bytes, checksum.hexdigest()


def default_snapshot_record(space_id: str, account: Account) -> SnapshotRecordModel:
    return SnapshotRecordModel(
        snapshotId=f"snapshot-{space_id}-{uuid4().hex[:12]}",
        memories=[],
        memoryTombstones=[],
        wishes=[],
        wishTombstones=[],
        anniversaries=[],
        weeklyTodos=[],
        tonightDinners=[],
        rituals=[],
        currentStatuses=[],
        whisperNotes=[],
        relationStatus="paired",
        updatedAt=utc_now(),
        lastUpdatedByAccountId=account.account_id,
    )


def make_snapshot_record(space_id: str, account: Account, relation_status: str) -> SnapshotRecordModel:
    return SnapshotRecordModel(
        snapshotId=f"snapshot-{space_id}-{uuid4().hex[:12]}",
        memories=[],
        memoryTombstones=[],
        wishes=[],
        wishTombstones=[],
        anniversaries=[],
        weeklyTodos=[],
        tonightDinners=[],
        rituals=[],
        currentStatuses=[],
        whisperNotes=[],
        relationStatus=relation_status,
        updatedAt=utc_now(),
        lastUpdatedByAccountId=account.account_id,
    )


def get_snapshot_record(space: Space, account: Account) -> SnapshotRecordModel:
    if space.snapshot is None:
        relation_status = "paired" if space.is_active else "invited"
        return make_snapshot_record(space.space_id, account, relation_status)
    return SnapshotRecordModel.model_validate(space.snapshot.payload_json)


def filter_memories_by_tombstones(
    memories: list[StoredRemoteMemoryModel],
    tombstones: list[StoredRemoteMemoryTombstoneModel],
) -> list[StoredRemoteMemoryModel]:
    deleted_ids = {tombstone.id for tombstone in tombstones}
    if not deleted_ids:
        return memories
    return [memory for memory in memories if memory.id not in deleted_ids]


def merge_memory_snapshot_state(
    existing_snapshot: SnapshotRecordModel | None,
    incoming_snapshot: SnapshotRecordModel,
) -> SnapshotRecordModel:
    if existing_snapshot is None:
        effective_memories = filter_memories_by_tombstones(
            incoming_snapshot.memories,
            incoming_snapshot.memoryTombstones,
        )
        return incoming_snapshot.model_copy(update={"memories": effective_memories})

    merged_tombstones_by_id: dict[str, StoredRemoteMemoryTombstoneModel] = {
        tombstone.id: tombstone for tombstone in existing_snapshot.memoryTombstones
    }
    for tombstone in incoming_snapshot.memoryTombstones:
        existing_tombstone = merged_tombstones_by_id.get(tombstone.id)
        if existing_tombstone is None or tombstone.deletedAt >= existing_tombstone.deletedAt:
            merged_tombstones_by_id[tombstone.id] = tombstone

    merged_memories_by_id: dict[str, StoredRemoteMemoryModel] = {
        memory.id: memory for memory in existing_snapshot.memories
    }
    for memory in incoming_snapshot.memories:
        existing_memory = merged_memories_by_id.get(memory.id)
        if existing_memory is None or memory.updatedAt >= existing_memory.updatedAt:
            merged_memories_by_id[memory.id] = memory

    merged_tombstones = sorted(
        merged_tombstones_by_id.values(),
        key=lambda item: item.deletedAt,
        reverse=True,
    )
    merged_memories = sorted(
        filter_memories_by_tombstones(
            list(merged_memories_by_id.values()),
            merged_tombstones,
        ),
        key=lambda item: item.updatedAt,
        reverse=True,
    )

    return incoming_snapshot.model_copy(
        update={
            "memories": merged_memories,
            "memoryTombstones": merged_tombstones,
        }
    )


def filter_wishes_by_tombstones(
    wishes: list[StoredRemoteWishModel],
    tombstones: list[StoredRemoteWishTombstoneModel],
) -> list[StoredRemoteWishModel]:
    deleted_ids = {tombstone.id for tombstone in tombstones}
    if not deleted_ids:
        return wishes
    return [wish for wish in wishes if wish.id not in deleted_ids]


def weekly_todo_debug_summary(todos: list[StoredRemoteWeeklyTodoModel]) -> str:
    if not todos:
        return "[]"

    summary = ",".join(
        f"{todo.id}|user={todo.createdByUserId}|updatedAt={todo.updatedAt.timestamp()}|completed={todo.isCompleted}|scheduledDate={todo.scheduledDate.isoformat() if todo.scheduledDate else 'nil'}"
        for todo in sorted(todos, key=lambda item: item.updatedAt)
    )
    return f"[{summary}]"


def merge_weekly_todo_models(
    existing_todo: StoredRemoteWeeklyTodoModel,
    incoming_todo: StoredRemoteWeeklyTodoModel,
) -> StoredRemoteWeeklyTodoModel:
    if incoming_todo.updatedAt > existing_todo.updatedAt:
        newer_todo = incoming_todo
        older_todo = existing_todo
    elif incoming_todo.updatedAt < existing_todo.updatedAt:
        newer_todo = existing_todo
        older_todo = incoming_todo
    else:
        newer_todo = incoming_todo
        older_todo = existing_todo

    return newer_todo.model_copy(
        update={
            "createdAt": min(existing_todo.createdAt, incoming_todo.createdAt),
            "createdByUserId": older_todo.createdByUserId,
        }
    )


def merge_weekly_todo_snapshot_state(
    existing_snapshot: SnapshotRecordModel | None,
    incoming_snapshot: SnapshotRecordModel,
) -> SnapshotRecordModel:
    if existing_snapshot is None:
        return incoming_snapshot

    merged_todos_by_id: dict[str, StoredRemoteWeeklyTodoModel] = {
        todo.id: todo for todo in existing_snapshot.weeklyTodos
    }
    for todo in incoming_snapshot.weeklyTodos:
        existing_todo = merged_todos_by_id.get(todo.id)
        if existing_todo is None:
            merged_todos_by_id[todo.id] = todo
            continue

        merged_todo = merge_weekly_todo_models(existing_todo, todo)
        logger.info(
            "snapshot weekly todo conflict id=%s existing_updated_at=%s incoming_updated_at=%s merged_updated_at=%s existing_completed=%s incoming_completed=%s merged_completed=%s",
            todo.id,
            existing_todo.updatedAt.timestamp(),
            todo.updatedAt.timestamp(),
            merged_todo.updatedAt.timestamp(),
            existing_todo.isCompleted,
            todo.isCompleted,
            merged_todo.isCompleted,
        )
        merged_todos_by_id[todo.id] = merged_todo

    merged_todos = sorted(
        merged_todos_by_id.values(),
        key=lambda item: item.updatedAt,
        reverse=True,
    )

    logger.info(
        "snapshot weekly todo merge existing=%s incoming=%s merged=%s",
        weekly_todo_debug_summary(existing_snapshot.weeklyTodos),
        weekly_todo_debug_summary(incoming_snapshot.weeklyTodos),
        weekly_todo_debug_summary(merged_todos),
    )

    return incoming_snapshot.model_copy(update={"weeklyTodos": merged_todos})


def wish_debug_summary(wishes: list[StoredRemoteWishModel]) -> str:
    if not wishes:
        return "[]"

    summary = ",".join(
        f"{wish.id}|user={wish.createdByUserId}|updatedAt={wish_updated_at_value(wish)}|category={wish.categoryRawValue}|status={wish.statusRawValue}"
        for wish in sorted(wishes, key=wish_updated_at_value)
    )
    return f"[{summary}]"


def wish_updated_at_value(wish: StoredRemoteWishModel) -> float:
    return wish.updatedAtTimestamp if wish.updatedAtTimestamp is not None else wish.updatedAt.timestamp()


def wish_field_updated_at_value(wish: StoredRemoteWishModel, field_name: str) -> float:
    field_value = getattr(wish, field_name)
    if field_value is None:
        return wish_updated_at_value(wish)
    return field_value.timestamp()


def resolve_wish_field(
    existing_wish: StoredRemoteWishModel,
    incoming_wish: StoredRemoteWishModel,
    *,
    value_fields: tuple[str, ...],
    updated_at_field: str,
) -> tuple[tuple[Any, ...], datetime]:
    existing_updated_at = wish_field_updated_at_value(existing_wish, updated_at_field)
    incoming_updated_at = wish_field_updated_at_value(incoming_wish, updated_at_field)
    if incoming_updated_at > existing_updated_at:
        source_wish = incoming_wish
    elif incoming_updated_at < existing_updated_at:
        source_wish = existing_wish
    elif wish_updated_at_value(incoming_wish) > wish_updated_at_value(existing_wish):
        source_wish = incoming_wish
    else:
        source_wish = existing_wish
    resolved_values = tuple(getattr(source_wish, field_name) for field_name in value_fields)
    resolved_updated_at = getattr(source_wish, updated_at_field) or source_wish.updatedAt
    return resolved_values, resolved_updated_at


def merge_wish_models(
    existing_wish: StoredRemoteWishModel,
    incoming_wish: StoredRemoteWishModel,
) -> StoredRemoteWishModel:
    base_wish = incoming_wish if wish_updated_at_value(incoming_wish) > wish_updated_at_value(existing_wish) else existing_wish
    title_value, title_updated_at = resolve_wish_field(
        existing_wish,
        incoming_wish,
        value_fields=("title",),
        updated_at_field="titleUpdatedAt",
    )
    detail_value, detail_updated_at = resolve_wish_field(
        existing_wish,
        incoming_wish,
        value_fields=("detail",),
        updated_at_field="detailUpdatedAt",
    )
    note_value, note_updated_at = resolve_wish_field(
        existing_wish,
        incoming_wish,
        value_fields=("note",),
        updated_at_field="noteUpdatedAt",
    )
    category_values, category_updated_at = resolve_wish_field(
        existing_wish,
        incoming_wish,
        value_fields=("categoryRawValue", "symbol"),
        updated_at_field="categoryUpdatedAt",
    )
    status_value, status_updated_at = resolve_wish_field(
        existing_wish,
        incoming_wish,
        value_fields=("statusRawValue",),
        updated_at_field="statusUpdatedAt",
    )
    target_text_value, target_text_updated_at = resolve_wish_field(
        existing_wish,
        incoming_wish,
        value_fields=("targetText",),
        updated_at_field="targetTextUpdatedAt",
    )
    merged_updated_at = max(
        existing_wish.updatedAt,
        incoming_wish.updatedAt,
        title_updated_at,
        detail_updated_at,
        note_updated_at,
        category_updated_at,
        status_updated_at,
        target_text_updated_at,
    )
    return base_wish.model_copy(
        update={
            "title": title_value[0],
            "titleUpdatedAt": title_updated_at,
            "detail": detail_value[0],
            "detailUpdatedAt": detail_updated_at,
            "note": note_value[0],
            "noteUpdatedAt": note_updated_at,
            "categoryRawValue": category_values[0],
            "symbol": category_values[1],
            "categoryUpdatedAt": category_updated_at,
            "statusRawValue": status_value[0],
            "statusUpdatedAt": status_updated_at,
            "targetText": target_text_value[0],
            "targetTextUpdatedAt": target_text_updated_at,
            "createdAt": min(existing_wish.createdAt, incoming_wish.createdAt),
            "updatedAt": merged_updated_at,
            "updatedAtTimestamp": merged_updated_at.timestamp(),
        }
    )


def merge_wish_snapshot_state(
    existing_snapshot: SnapshotRecordModel | None,
    incoming_snapshot: SnapshotRecordModel,
) -> SnapshotRecordModel:
    if existing_snapshot is None:
        effective_wishes = filter_wishes_by_tombstones(
            incoming_snapshot.wishes,
            incoming_snapshot.wishTombstones,
        )
        return incoming_snapshot.model_copy(update={"wishes": effective_wishes})

    merged_tombstones_by_id: dict[str, StoredRemoteWishTombstoneModel] = {
        tombstone.id: tombstone for tombstone in existing_snapshot.wishTombstones
    }
    for tombstone in incoming_snapshot.wishTombstones:
        existing_tombstone = merged_tombstones_by_id.get(tombstone.id)
        if existing_tombstone is None or tombstone.deletedAt >= existing_tombstone.deletedAt:
            merged_tombstones_by_id[tombstone.id] = tombstone

    merged_wishes_by_id: dict[str, StoredRemoteWishModel] = {
        wish.id: wish for wish in existing_snapshot.wishes
    }
    for wish in incoming_snapshot.wishes:
        existing_wish = merged_wishes_by_id.get(wish.id)
        if existing_wish is not None:
            merged_wish = merge_wish_models(existing_wish, wish)
            logger.info(
                "snapshot wish conflict id=%s existing_updated_at=%s incoming_updated_at=%s merged_updated_at=%s existing_category=%s incoming_category=%s merged_category=%s",
                wish.id,
                wish_updated_at_value(existing_wish),
                wish_updated_at_value(wish),
                wish_updated_at_value(merged_wish),
                existing_wish.categoryRawValue,
                wish.categoryRawValue,
                merged_wish.categoryRawValue,
            )
            merged_wishes_by_id[wish.id] = merged_wish
            continue
        merged_wishes_by_id[wish.id] = wish

    merged_tombstones = sorted(
        merged_tombstones_by_id.values(),
        key=lambda item: item.deletedAt,
        reverse=True,
    )
    merged_wishes = sorted(
        filter_wishes_by_tombstones(
            list(merged_wishes_by_id.values()),
            merged_tombstones,
        ),
        key=wish_updated_at_value,
        reverse=True,
    )

    logger.info(
        "snapshot wish merge existing=%s incoming=%s merged=%s tombstones=%s",
        wish_debug_summary(existing_snapshot.wishes),
        wish_debug_summary(incoming_snapshot.wishes),
        wish_debug_summary(merged_wishes),
        len(merged_tombstones),
    )

    return incoming_snapshot.model_copy(
        update={
            "wishes": merged_wishes,
            "wishTombstones": merged_tombstones,
        }
    )


def build_snapshot_response(session: Session, space: Space, account: Account) -> dict[str, Any]:
    snapshot = get_snapshot_record(space, account)
    effective_memories = filter_memories_by_tombstones(snapshot.memories, snapshot.memoryTombstones)
    effective_wishes = filter_wishes_by_tombstones(snapshot.wishes, snapshot.wishTombstones)
    logger.info(
        "snapshot GET response space=%s account=%s memories=%s memory_tombstones=%s wishes=%s wish_tombstones=%s whisperNotes=%s",
        space.space_id,
        account.account_id,
        len(effective_memories),
        len(snapshot.memoryTombstones),
        len(effective_wishes),
        len(snapshot.wishTombstones),
        len(snapshot.whisperNotes),
    )
    return RemoteSnapshotResponseModel(
        snapshotId=snapshot.snapshotId,
        spaceId=space.space_id,
        currentUserId=account.current_user_id,
        partnerUserId=resolve_partner_user_id(session, space, account),
        isSharedSpace=len(space.members) > 1,
        memories=effective_memories,
        memoryTombstones=snapshot.memoryTombstones,
        wishes=effective_wishes,
        wishTombstones=snapshot.wishTombstones,
        anniversaries=snapshot.anniversaries,
        weeklyTodos=snapshot.weeklyTodos,
        tonightDinners=snapshot.tonightDinners,
        rituals=snapshot.rituals,
        currentStatuses=snapshot.currentStatuses,
        whisperNotes=snapshot.whisperNotes,
        relationStatus=snapshot.relationStatus,
        updatedAt=snapshot.updatedAt,
    ).model_dump(mode="json")


def normalize_snapshot_payload(
    raw_payload: dict[str, Any],
    path_space_id: str,
    account: Account,
    partner_user_id: str | None,
) -> SnapshotRecordModel:
    try:
        stored_payload = StoredSnapshotRequestModel.model_validate(raw_payload)
        if stored_payload.scope.spaceId != path_space_id:
            raise APIError(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                code="invalid_payload",
                message="payload 中的 scope.spaceId 与路径不一致。",
            )
        if stored_payload.scope.currentUserId != account.current_user_id:
            raise APIError(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                code="invalid_payload",
                message="payload 中的 currentUserId 与当前 token 不一致。",
            )
        logger.info(
            "snapshot PUT normalized stored payload space=%s account=%s memories=%s memory_tombstones=%s wishes=%s wish_tombstones=%s whisperNotes=%s",
            path_space_id,
            account.account_id,
            len(stored_payload.memories),
            len(stored_payload.memoryTombstones),
            len(stored_payload.wishes),
            len(stored_payload.wishTombstones),
            len(stored_payload.whisperNotes),
        )
        effective_memories = filter_memories_by_tombstones(
            stored_payload.memories,
            stored_payload.memoryTombstones,
        )
        effective_wishes = filter_wishes_by_tombstones(
            stored_payload.wishes,
            stored_payload.wishTombstones,
        )
        return SnapshotRecordModel(
            snapshotId=f"snapshot-{path_space_id}-{uuid4().hex[:12]}",
            memories=effective_memories,
            memoryTombstones=stored_payload.memoryTombstones,
            wishes=effective_wishes,
            wishTombstones=stored_payload.wishTombstones,
            anniversaries=stored_payload.anniversaries,
            weeklyTodos=stored_payload.weeklyTodos,
            tonightDinners=stored_payload.tonightDinners,
            rituals=stored_payload.rituals,
            currentStatuses=stored_payload.currentStatuses,
            whisperNotes=stored_payload.whisperNotes,
            relationStatus=stored_payload.relationStatusRawValue,
            updatedAt=utc_now(),
            lastUpdatedByAccountId=account.account_id,
        )
    except APIError:
        raise
    except ValidationError:
        pass

    try:
        remote_payload = RemoteSnapshotResponseModel.model_validate(raw_payload)
        if remote_payload.spaceId != path_space_id:
            raise APIError(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                code="invalid_payload",
                message="payload 中的 spaceId 与路径不一致。",
            )
        if remote_payload.currentUserId != account.current_user_id:
            raise APIError(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                code="invalid_payload",
                message="payload 中的 currentUserId 与当前 token 不一致。",
            )
        if remote_payload.partnerUserId != partner_user_id:
            raise APIError(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                code="invalid_payload",
                message="payload 中的 partnerUserId 与当前空间不一致。",
            )
        logger.info(
            "snapshot PUT normalized remote payload space=%s account=%s memories=%s memory_tombstones=%s wishes=%s wish_tombstones=%s whisperNotes=%s",
            path_space_id,
            account.account_id,
            len(remote_payload.memories),
            len(remote_payload.memoryTombstones),
            len(remote_payload.wishes),
            len(remote_payload.wishTombstones),
            len(remote_payload.whisperNotes),
        )
        effective_memories = filter_memories_by_tombstones(
            remote_payload.memories,
            remote_payload.memoryTombstones,
        )
        effective_wishes = filter_wishes_by_tombstones(
            remote_payload.wishes,
            remote_payload.wishTombstones,
        )
        return SnapshotRecordModel(
            snapshotId=f"snapshot-{path_space_id}-{uuid4().hex[:12]}",
            memories=effective_memories,
            memoryTombstones=remote_payload.memoryTombstones,
            wishes=effective_wishes,
            wishTombstones=remote_payload.wishTombstones,
            anniversaries=remote_payload.anniversaries,
            weeklyTodos=remote_payload.weeklyTodos,
            tonightDinners=remote_payload.tonightDinners,
            rituals=remote_payload.rituals,
            currentStatuses=remote_payload.currentStatuses,
            whisperNotes=remote_payload.whisperNotes,
            relationStatus=remote_payload.relationStatus,
            updatedAt=utc_now(),
            lastUpdatedByAccountId=account.account_id,
        )
    except APIError:
        raise
    except ValidationError as exc:
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="invalid_payload",
            message="snapshot payload 既不符合当前 iOS push 结构，也不符合远端 snapshot 结构。",
            detail=exc.errors(),
        ) from exc


def save_snapshot(session: Session, space: Space, snapshot_record: SnapshotRecordModel) -> None:
    existing_snapshot = (
        SnapshotRecordModel.model_validate(space.snapshot.payload_json)
        if space.snapshot is not None
        else None
    )
    merged_snapshot = merge_memory_snapshot_state(existing_snapshot, snapshot_record)
    merged_snapshot = merge_weekly_todo_snapshot_state(existing_snapshot, merged_snapshot)
    merged_snapshot = merge_wish_snapshot_state(existing_snapshot, merged_snapshot)

    if space.snapshot is None:
        session.add(
            SpaceSnapshot(
                snapshot_id=merged_snapshot.snapshotId,
                space_id=space.space_id,
                payload_json=merged_snapshot.model_dump(mode="json"),
                updated_by_account_id=merged_snapshot.lastUpdatedByAccountId,
                updated_at=merged_snapshot.updatedAt,
            )
        )
    else:
        space.snapshot.snapshot_id = merged_snapshot.snapshotId
        space.snapshot.payload_json = merged_snapshot.model_dump(mode="json")
        space.snapshot.updated_by_account_id = merged_snapshot.lastUpdatedByAccountId
        space.snapshot.updated_at = merged_snapshot.updatedAt
    logger.info(
        "snapshot persisted space=%s updatedBy=%s memories=%s memory_tombstones=%s wishes=%s wish_tombstones=%s whisperNotes=%s",
        space.space_id,
        merged_snapshot.lastUpdatedByAccountId,
        len(merged_snapshot.memories),
        len(merged_snapshot.memoryTombstones),
        len(merged_snapshot.wishes),
        len(merged_snapshot.wishTombstones),
        len(merged_snapshot.whisperNotes),
    )
    session.commit()
    session.refresh(space)


def create_unique_space_id(session: Session) -> str:
    while True:
        space_id = f"space-{uuid4().hex[:12]}"
        if session.scalar(select(Space).where(Space.space_id == space_id)) is None:
            return space_id


def create_unique_invite_code(session: Session) -> str:
    while True:
        invite_code = uuid4().hex[:8].upper()
        if session.scalar(select(Space).where(Space.invite_code == invite_code)) is None:
            return invite_code


def get_active_space_for_account(session: Session, account: Account) -> Space | None:
    return session.scalar(
        select(Space)
        .join(SpaceMember, SpaceMember.space_id == Space.space_id)
        .where(
            SpaceMember.account_id == account.account_id,
            Space.is_active.is_(True),
        )
        .limit(1)
    )


def ensure_account_has_no_active_space(session: Session, account: Account) -> None:
    active_space = get_active_space_for_account(session, account)
    if active_space is None:
        return
    raise APIError(
        status_code=status.HTTP_409_CONFLICT,
        code="active_space_exists",
        message="当前账号已经在一个生效中的共享空间里，暂时不能再创建或加入新的空间。",
        detail={"spaceId": active_space.space_id},
    )


def get_member_role(space: Space, account_id: str) -> str:
    for member in space.members:
        if member.account_id == account_id:
            return member.role
    raise APIError(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        code="member_missing",
        message="空间成员状态异常。",
    )


def get_partner_account(session: Session, space: Space, account: Account) -> Account | None:
    for member in space.members:
        if member.account_id == account.account_id:
            continue
        partner_account = session.scalar(select(Account).where(Account.account_id == member.account_id))
        if partner_account is not None:
            return partner_account
    return None


def relation_status_for_space(space: Space) -> str:
    if space.is_active and len(space.members) >= 2:
        return "paired"
    return "invited"


def build_space_connection_response(session: Session, space: Space, account: Account) -> SpaceConnectionResponse:
    partner_account = get_partner_account(session, space, account)
    return SpaceConnectionResponse(
        spaceId=space.space_id,
        title=space.title,
        inviteCode=space.invite_code or "",
        isActivated=space.is_active,
        memberCount=len(space.members),
        currentRole=get_member_role(space, account.account_id),
        relationStatus=relation_status_for_space(space),
        currentAccountId=account.account_id,
        currentUserId=account.current_user_id,
        partnerAccountId=partner_account.account_id if partner_account is not None else None,
        partnerUserId=partner_account.current_user_id if partner_account is not None else None,
    )


def build_space_participant_summary(space: Space, account: Account) -> SpaceParticipantSummary:
    return SpaceParticipantSummary(
        accountId=account.account_id,
        displayName=account.display_name,
        providerName=account.provider_name,
        accountHint=account.account_hint,
        currentUserId=account.current_user_id,
        role=get_member_role(space, account.account_id),
    )


def build_space_status_response(session: Session, space: Space, account: Account) -> SpaceStatusResponse:
    partner_account = get_partner_account(session, space, account)
    current_account_summary = build_space_participant_summary(space, account)
    partner_summary = (
        build_space_participant_summary(space, partner_account)
        if partner_account is not None
        else None
    )
    return SpaceStatusResponse(
        spaceId=space.space_id,
        title=space.title,
        inviteCode=space.invite_code or "",
        isActivated=space.is_active,
        memberCount=len(space.members),
        currentRole=current_account_summary.role,
        relationStatus=relation_status_for_space(space),
        currentAccountId=account.account_id,
        currentUserId=account.current_user_id,
        partnerAccountId=partner_account.account_id if partner_account is not None else None,
        partnerUserId=partner_account.current_user_id if partner_account is not None else None,
        currentAccount=current_account_summary,
        partner=partner_summary,
    )


def build_memory_asset_upload_response(asset: MemoryAsset) -> MemoryAssetUploadResponse:
    return MemoryAssetUploadResponse(
        assetId=asset.asset_id,
        memoryId=asset.memory_id,
        spaceId=asset.space_id,
        storageKey=asset.storage_key,
        mimeType=asset.mime_type,
        byteSize=asset.byte_size,
        checksum=asset.checksum,
        width=asset.width,
        height=asset.height,
        createdAt=asset.created_at,
        uploadedByUserId=asset.uploaded_by_user_id,
    )


def initialize_space_snapshot(session: Session, space: Space, account: Account) -> None:
    snapshot_record = make_snapshot_record(
        space_id=space.space_id,
        account=account,
        relation_status=relation_status_for_space(space),
    )
    session.add(
        SpaceSnapshot(
            snapshot_id=snapshot_record.snapshotId,
            space_id=space.space_id,
            payload_json=snapshot_record.model_dump(mode="json"),
            updated_by_account_id=account.account_id,
            updated_at=snapshot_record.updatedAt,
        )
    )


def sync_space_snapshot_status(session: Session, space: Space, account: Account) -> None:
    relation_status = relation_status_for_space(space)
    if space.snapshot is None:
        initialize_space_snapshot(session, space, account)
        return

    snapshot_record = SnapshotRecordModel.model_validate(space.snapshot.payload_json)
    snapshot_record.relationStatus = relation_status
    snapshot_record.updatedAt = utc_now()
    snapshot_record.lastUpdatedByAccountId = account.account_id
    space.snapshot.payload_json = snapshot_record.model_dump(mode="json")
    space.snapshot.updated_by_account_id = account.account_id
    space.snapshot.updated_at = snapshot_record.updatedAt


def normalize_space_title(account: Account, raw_title: str | None) -> str:
    if raw_title and raw_title.strip():
        return raw_title.strip()
    return f"{account.display_name} 的共享空间"


@app.post("/auth/login", response_model=AuthenticatedAccountResponse)
async def login(
    payload: LoginRequest,
    db: Session = Depends(get_db),
) -> AuthenticatedAccountResponse:
    account = authenticate_account(db, payload)
    return build_authenticated_account_response(account)


@app.post("/auth/demo-login", response_model=AuthenticatedAccountResponse)
async def demo_login(
    payload: DemoLoginRequest | None = None,
    db: Session = Depends(get_db),
) -> AuthenticatedAccountResponse:
    account = find_account_by_login_hint(db, payload)
    return build_authenticated_account_response(account)


@app.post("/spaces", response_model=SpaceConnectionResponse)
async def create_space(
    payload: CreateSpaceRequest | None = None,
    authorization: str | None = Header(default=None),
    x_couple_space_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Account-ID"),
    x_couple_space_session_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Session-Account-ID"),
    db: Session = Depends(get_db),
) -> SpaceConnectionResponse:
    account = require_account(
        session=db,
        authorization=authorization,
        account_id_header=x_couple_space_account_id,
        session_account_id_header=x_couple_space_session_account_id,
    )
    ensure_account_has_no_active_space(db, account)

    space = Space(
        space_id=create_unique_space_id(db),
        title=normalize_space_title(account, payload.title if payload is not None else None),
        invite_code=create_unique_invite_code(db),
        is_active=False,
        created_by_account_id=account.account_id,
    )
    db.add(space)
    db.flush()

    db.add(
        SpaceMember(
            space_id=space.space_id,
            account_id=account.account_id,
            role="owner",
        )
    )
    db.flush()
    db.expire_all()
    created_space = get_space_or_raise(db, space.space_id)
    initialize_space_snapshot(db, created_space, account)
    db.commit()

    db.expire_all()
    created_space = get_space_or_raise(db, space.space_id)
    return build_space_connection_response(db, created_space, account)


@app.post("/spaces/join", response_model=SpaceConnectionResponse)
async def join_space(
    payload: JoinSpaceRequest,
    authorization: str | None = Header(default=None),
    x_couple_space_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Account-ID"),
    x_couple_space_session_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Session-Account-ID"),
    db: Session = Depends(get_db),
) -> SpaceConnectionResponse:
    account = require_account(
        session=db,
        authorization=authorization,
        account_id_header=x_couple_space_account_id,
        session_account_id_header=x_couple_space_session_account_id,
    )

    invite_code = payload.inviteCode.strip().upper()
    if not invite_code:
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="invalid_invite_code",
            message="inviteCode 不能为空。",
        )

    space = db.scalar(
        select(Space)
        .options(selectinload(Space.members), selectinload(Space.snapshot))
        .where(Space.invite_code == invite_code)
    )
    if space is None:
        raise APIError(
            status_code=status.HTTP_404_NOT_FOUND,
            code="invite_not_found",
            message="邀请码不存在或已失效。",
        )

    if any(member.account_id == account.account_id for member in space.members):
        raise APIError(
            status_code=status.HTTP_409_CONFLICT,
            code="already_joined",
            message="当前账号已经在这个共享空间里。",
            detail={"spaceId": space.space_id},
        )

    ensure_account_has_no_active_space(db, account)

    if len(space.members) >= 2:
        raise APIError(
            status_code=status.HTTP_409_CONFLICT,
            code="space_full",
            message="这个共享空间已经有两位成员，暂时不能再加入。",
            detail={"spaceId": space.space_id},
        )

    db.add(
        SpaceMember(
            space_id=space.space_id,
            account_id=account.account_id,
            role="partner",
        )
    )
    space.is_active = True
    space.updated_at = utc_now()
    db.flush()
    db.expire_all()
    joined_space = get_space_or_raise(db, space.space_id)
    sync_space_snapshot_status(db, joined_space, account)
    db.commit()

    db.expire_all()
    joined_space = get_space_or_raise(db, space.space_id)
    return build_space_connection_response(db, joined_space, account)


@app.get("/spaces/{space_id}", response_model=SpaceStatusResponse)
async def get_space_status(
    space_id: str,
    authorization: str | None = Header(default=None),
    x_couple_space_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Account-ID"),
    x_couple_space_session_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Session-Account-ID"),
    db: Session = Depends(get_db),
) -> SpaceStatusResponse:
    account = require_account(
        session=db,
        authorization=authorization,
        account_id_header=x_couple_space_account_id,
        session_account_id_header=x_couple_space_session_account_id,
    )
    space = ensure_space_access(db, space_id, account)
    return build_space_status_response(db, space, account)


@app.post(
    "/spaces/{space_id}/memory-assets",
    response_model=MemoryAssetUploadResponse,
    status_code=status.HTTP_201_CREATED,
)
async def upload_memory_asset(
    space_id: str,
    memoryId: str,
    request: Request,
    authorization: str | None = Header(default=None),
    x_couple_space_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Account-ID"),
    x_couple_space_session_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Session-Account-ID"),
    db: Session = Depends(get_db),
) -> MemoryAssetUploadResponse:
    account = require_account(
        session=db,
        authorization=authorization,
        account_id_header=x_couple_space_account_id,
        session_account_id_header=x_couple_space_session_account_id,
    )
    ensure_space_access(db, space_id, account)
    logger.info(
        "memory asset upload hit space=%s memory=%s content_type=%s account=%s",
        space_id,
        memoryId,
        request.headers.get("Content-Type"),
        account.account_id,
    )

    normalized_memory_id = memoryId.strip()
    if not normalized_memory_id:
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="invalid_memory_id",
            message="memoryId 不能为空。",
        )

    mime_type = request.headers.get("Content-Type", "").split(";", 1)[0].strip().lower()
    if not mime_type:
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="missing_content_type",
            message="图片上传请求缺少 Content-Type。",
        )

    extension = resolve_memory_asset_extension(mime_type)
    content_length = request.headers.get("Content-Length")
    if content_length:
        try:
            declared_length = int(content_length)
        except ValueError:
            declared_length = None
        else:
            if declared_length > settings.memory_asset_max_bytes:
                raise APIError(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    code="memory_asset_too_large",
                    message="图片暂时超过当前测试环境允许的大小。",
                    detail={"maxBytes": settings.memory_asset_max_bytes, "contentLength": declared_length},
                )

    asset_id = f"asset-{uuid4().hex[:24]}"
    storage_key = build_memory_asset_storage_key(space_id, asset_id, extension)
    destination = memory_asset_file_path(storage_key)
    logger.info(
        "memory asset upload reading body space=%s memory=%s content_length=%s",
        space_id,
        normalized_memory_id,
        content_length,
    )
    byte_size, checksum = await stream_memory_asset_file(
        request,
        destination,
        max_bytes=settings.memory_asset_max_bytes,
        space_id=space_id,
        memory_id=normalized_memory_id,
    )
    logger.info(
        "memory asset upload body ready space=%s memory=%s bytes=%s",
        space_id,
        normalized_memory_id,
        byte_size,
    )

    asset = MemoryAsset(
        asset_id=asset_id,
        memory_id=normalized_memory_id,
        space_id=space_id,
        storage_key=storage_key,
        mime_type=mime_type,
        byte_size=byte_size,
        checksum=checksum,
        width=None,
        height=None,
        uploaded_by_account_id=account.account_id,
        uploaded_by_user_id=account.current_user_id,
    )
    db.add(asset)
    db.commit()
    db.refresh(asset)

    logger.info(
        "memory asset uploaded space=%s memory=%s asset=%s bytes=%s",
        space_id,
        normalized_memory_id,
        asset_id,
        byte_size,
    )

    return build_memory_asset_upload_response(asset)


@app.get("/spaces/{space_id}/snapshot", response_model=RemoteSnapshotResponseModel)
async def pull_snapshot(
    space_id: str,
    accountId: str | None = None,
    currentUserId: str | None = None,
    partnerUserId: str | None = None,
    authorization: str | None = Header(default=None),
    x_couple_space_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Account-ID"),
    x_couple_space_session_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Session-Account-ID"),
    db: Session = Depends(get_db),
) -> JSONResponse:
    account = require_account(
        session=db,
        authorization=authorization,
        account_id_header=x_couple_space_account_id or accountId,
        session_account_id_header=x_couple_space_session_account_id,
    )
    space = ensure_space_access(db, space_id, account)

    if currentUserId and currentUserId != account.current_user_id:
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="invalid_request",
            message="query 里的 currentUserId 与当前 token 不一致。",
        )

    expected_partner_user_id = resolve_partner_user_id(db, space, account)
    if partnerUserId and partnerUserId != expected_partner_user_id:
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="invalid_request",
            message="query 里的 partnerUserId 与当前空间关系不一致。",
        )

    response_payload = build_snapshot_response(db, space, account)
    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content=response_payload,
        headers={"X-CoupleSpace-Snapshot-ID": response_payload["snapshotId"]},
    )


@app.put("/spaces/{space_id}/snapshot", response_model=RemoteSnapshotResponseModel)
async def push_snapshot(
    space_id: str,
    request: Request,
    authorization: str | None = Header(default=None),
    x_couple_space_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Account-ID"),
    x_couple_space_session_account_id: str | None = Header(default=None, alias="X-CoupleSpace-Session-Account-ID"),
    db: Session = Depends(get_db),
) -> JSONResponse:
    account = require_account(
        session=db,
        authorization=authorization,
        account_id_header=x_couple_space_account_id,
        session_account_id_header=x_couple_space_session_account_id,
    )
    space = ensure_space_access(db, space_id, account)

    try:
        raw_payload = await request.json()
    except json.JSONDecodeError as exc:
        raise APIError(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="invalid_payload",
            message="请求体不是合法 JSON。",
            detail=str(exc),
        ) from exc

    normalized_snapshot = normalize_snapshot_payload(
        raw_payload=raw_payload,
        path_space_id=space_id,
        account=account,
        partner_user_id=resolve_partner_user_id(db, space, account),
    )
    save_snapshot(db, space, normalized_snapshot)

    refreshed_space = ensure_space_access(db, space_id, account)
    response_payload = build_snapshot_response(db, refreshed_space, account)
    return JSONResponse(
        status_code=status.HTTP_200_OK,
        content=response_payload,
        headers={"X-CoupleSpace-Snapshot-ID": response_payload["snapshotId"]},
    )
