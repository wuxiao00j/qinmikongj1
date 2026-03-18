from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from backend.auth import ensure_password_hash
from backend.models import Account, Space, SpaceMember, SpaceSnapshot


BASE_DIR = Path(__file__).resolve().parent
SEED_PATH = BASE_DIR / "data" / "seed.json"


def _default_invite_code(space_id: str) -> str:
    compact = "".join(char for char in space_id.upper() if char.isalnum())
    return (compact[-8:] or "COUPLE01")[:8]


def load_seed_payload(seed_path: Path = SEED_PATH) -> dict[str, Any]:
    if not seed_path.exists():
        raise RuntimeError(f"Missing seed file: {seed_path}")
    return json.loads(seed_path.read_text(encoding="utf-8"))


def seed_database(session: Session, payload: dict[str, Any] | None = None) -> None:
    seed_payload = payload or load_seed_payload()
    account_map: dict[str, Account] = {}

    for raw_account in seed_payload.get("accounts", []):
        account_id = raw_account["accountId"]
        password_hash = ensure_password_hash(raw_account.get("password"), None)
        account = session.scalar(select(Account).where(Account.account_id == account_id))
        if account is None:
            account = Account(
                account_id=account_id,
                display_name=raw_account["displayName"],
                provider_name=raw_account["providerName"],
                account_hint=raw_account.get("accountHint"),
                password_hash=password_hash,
                access_token=raw_account["accessToken"],
                current_user_id=raw_account["currentUserId"],
                partner_user_id=raw_account.get("partnerUserId"),
            )
            session.add(account)
        else:
            account.display_name = raw_account["displayName"]
            account.provider_name = raw_account["providerName"]
            account.account_hint = raw_account.get("accountHint")
            account.password_hash = ensure_password_hash(raw_account.get("password"), account.password_hash)
            account.access_token = raw_account["accessToken"]
            account.current_user_id = raw_account["currentUserId"]
            account.partner_user_id = raw_account.get("partnerUserId")
        account_map[account_id] = account

    session.flush()

    for space_index, (space_id, raw_space) in enumerate(seed_payload.get("spaces", {}).items()):
        existing_space = session.scalar(select(Space).where(Space.space_id == space_id))
        created_by_account_id = raw_space.get("memberAccountIds", [None])[0]
        if existing_space is None:
            existing_space = Space(
                space_id=space_id,
                title=raw_space.get("title") or space_id,
                invite_code=raw_space.get("inviteCode") or f"{_default_invite_code(space_id)}{space_index}",
                is_active=raw_space.get("isActive", True),
                created_by_account_id=created_by_account_id,
            )
            session.add(existing_space)
        else:
            existing_space.title = raw_space.get("title") or existing_space.title or space_id
            existing_space.invite_code = raw_space.get("inviteCode") or existing_space.invite_code or f"{_default_invite_code(space_id)}{space_index}"
            existing_space.is_active = raw_space.get("isActive", True)
            existing_space.created_by_account_id = created_by_account_id

        session.flush()

        member_account_ids = raw_space.get("memberAccountIds", [])
        for member_index, account_id in enumerate(member_account_ids):
            existing_member = session.scalar(
                select(SpaceMember).where(
                    SpaceMember.space_id == space_id,
                    SpaceMember.account_id == account_id,
                )
            )
            if existing_member is None:
                session.add(
                    SpaceMember(
                        space_id=space_id,
                        account_id=account_id,
                        role="owner" if member_index == 0 else "partner",
                    )
                )

        snapshot_payload = raw_space.get("snapshot")
        if snapshot_payload is None:
            continue

        existing_snapshot = session.scalar(select(SpaceSnapshot).where(SpaceSnapshot.space_id == space_id))
        if existing_snapshot is None:
            session.add(
                SpaceSnapshot(
                    snapshot_id=snapshot_payload["snapshotId"],
                    space_id=space_id,
                    payload_json=snapshot_payload,
                    updated_by_account_id=snapshot_payload.get("lastUpdatedByAccountId"),
                )
            )
        else:
            existing_snapshot.snapshot_id = snapshot_payload["snapshotId"]
            existing_snapshot.payload_json = snapshot_payload
            existing_snapshot.updated_by_account_id = snapshot_payload.get("lastUpdatedByAccountId")

    session.commit()
