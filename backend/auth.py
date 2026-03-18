from __future__ import annotations

import base64
import hashlib
import hmac
import secrets


PASSWORD_HASH_SCHEME = "pbkdf2_sha256"
PASSWORD_HASH_ITERATIONS = 120_000


def hash_password(password: str, *, salt: str | None = None, iterations: int = PASSWORD_HASH_ITERATIONS) -> str:
    normalized_password = password.encode("utf-8")
    normalized_salt = salt or secrets.token_hex(16)
    derived_key = hashlib.pbkdf2_hmac(
        "sha256",
        normalized_password,
        normalized_salt.encode("utf-8"),
        iterations,
    )
    encoded_hash = base64.b64encode(derived_key).decode("utf-8")
    return f"{PASSWORD_HASH_SCHEME}${iterations}${normalized_salt}${encoded_hash}"


def verify_password(password: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False

    try:
        scheme, raw_iterations, salt, encoded_hash = password_hash.split("$", 3)
    except ValueError:
        return False

    if scheme != PASSWORD_HASH_SCHEME:
        return False

    try:
        iterations = int(raw_iterations)
    except ValueError:
        return False

    expected_hash = hash_password(password, salt=salt, iterations=iterations)
    return hmac.compare_digest(expected_hash, password_hash)


def ensure_password_hash(password: str | None, current_hash: str | None) -> str | None:
    if password is None:
        return current_hash

    if current_hash and verify_password(password, current_hash):
        return current_hash

    return hash_password(password)
