"""Auth router — login, logout, status, registration, and user-management endpoints."""

import hashlib
import hmac
import logging
import os
import secrets

from fastapi import APIRouter, Cookie, Depends, Header, HTTPException, Request, Response, status
from pydantic import BaseModel, Field, field_validator

# SameSite=None lets the cookie work when the browser accesses the frontend via
# 127.0.0.1 and the backend via localhost (different origins on the same machine).
# Browsers require Secure=True for SameSite=None, but that needs HTTPS — so in
# local dev we fall back to SameSite=Lax and tell users to use localhost:// URLs.
_SECURE = os.getenv("AUTH_COOKIE_SECURE", "false").lower() == "true"
_SAMESITE = "none" if _SECURE else "lax"

from deeptutor.services.auth import (
    AUTH_ACCESS_TOKEN_MINUTES,
    AUTH_ENABLED,
    POCKETBASE_ENABLED,
    TOKEN_EXPIRE_HOURS,
    TokenPayload,
    add_user,
    authenticate,
    authenticate_pb,
    create_token,
    decode_token,
    delete_user,
    is_first_user,
    list_users,
    register_pb,
    set_role,
)

logger = logging.getLogger(__name__)

router = APIRouter()

_COOKIE_NAME = "dt_token"


def _session_cookie_max_seconds() -> int:
    if AUTH_ACCESS_TOKEN_MINUTES > 0:
        return AUTH_ACCESS_TOKEN_MINUTES * 60
    return TOKEN_EXPIRE_HOURS * 3600


def _reject_disabled_user(record: dict) -> None:
    if bool(record.get("disabled")):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been disabled. Contact an administrator.",
        )


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class LoginRequest(BaseModel):
    """Payload for the POST /login endpoint."""

    username: str
    password: str


class RegisterRequest(BaseModel):
    """Payload for the POST /register endpoint."""

    username: str
    password: str

    @field_validator("username")
    @classmethod
    def username_valid(cls, v: str) -> str:
        import re

        v = v.strip()
        if not v:
            raise ValueError("Email cannot be empty")
        # Accept standard email addresses (used by PocketBase mode) or plain
        # usernames (used by the built-in SQLite/JSON auth mode).
        email_re = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
        plain_re = re.compile(r"^[A-Za-z0-9_\-.]{3,64}$")
        if not email_re.match(v) and not plain_re.match(v):
            raise ValueError("Enter a valid email address")
        return v

    @field_validator("password")
    @classmethod
    def password_valid(cls, v: str) -> str:
        from deeptutor.services.password_policy import validate_password_strength

        validate_password_strength(v)
        return v


class MfaActivateRequest(BaseModel):
    """TOTP code to confirm MFA enrollment."""

    code: str = Field(min_length=6, max_length=12)


class SetRoleRequest(BaseModel):
    """Payload for the PUT /users/{username}/role endpoint."""

    role: str

    @field_validator("role")
    @classmethod
    def role_valid(cls, v: str) -> str:
        from deeptutor.multi_user.identity import ALL_ROLES

        if v not in ALL_ROLES:
            raise ValueError(f"Role must be one of: {', '.join(sorted(ALL_ROLES))}")
        return v


class AuthStatusResponse(BaseModel):
    """Response body for the GET /status endpoint."""

    enabled: bool
    authenticated: bool
    user_id: str | None = None
    username: str | None = None
    role: str | None = None
    is_admin: bool = False


class UserInfo(BaseModel):
    """Single user record returned by the GET /users endpoint."""

    id: str = ""
    username: str
    role: str
    created_at: str
    disabled: bool = False


# ---------------------------------------------------------------------------
# Shared helper — extract token from cookie or Bearer header
# ---------------------------------------------------------------------------


def _bearer_token_from_header(authorization: str | None) -> str | None:
    """Parse ``Authorization: Bearer <token>`` without using ``HTTPBearer``.

    ``HTTPBearer`` is a class-based dependency whose ``__call__`` is annotated
    ``request: Request``. FastAPI doesn't inject a Request into WebSocket
    dependency resolution, which makes ``HTTPBearer`` raise ``TypeError`` the
    moment a router with this dep mounts a WS endpoint. Doing the parse by
    hand keeps ``require_auth`` HTTP/WS-symmetric.
    """
    if not authorization:
        return None
    parts = authorization.split(None, 1)
    if len(parts) == 2 and parts[0].lower() == "bearer":
        token = parts[1].strip()
        return token or None
    return None


def _extract_token(authorization: str | None, dt_token: str | None) -> str | None:
    return _bearer_token_from_header(authorization) or dt_token


# ---------------------------------------------------------------------------
# Dependencies — reusable auth guards for other routers
# ---------------------------------------------------------------------------


def require_auth(
    authorization: str | None = Header(default=None, alias="Authorization"),
    dt_token: str | None = Cookie(default=None),
) -> TokenPayload | None:
    """
    FastAPI dependency that enforces authentication when AUTH_ENABLED=true.

    Accepts the JWT from either:
      - Authorization: Bearer <token> header
      - dt_token cookie

    Works on both HTTP and WebSocket routes — ``Header`` and ``Cookie`` are
    WS-compatible, while ``HTTPBearer`` (which we used to use here) is not.

    Returns the authenticated TokenPayload, or None if auth is disabled.
    Raises HTTP 401 if auth is enabled but the token is missing or invalid.
    """
    if not AUTH_ENABLED:
        from deeptutor.multi_user.context import set_current_user
        from deeptutor.multi_user.paths import local_admin_user

        set_current_user(local_admin_user())
        return None

    token = _extract_token(authorization, dt_token)

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    from deeptutor.multi_user.context import set_current_user, user_from_token_payload

    set_current_user(user_from_token_payload(payload))
    return payload


def require_admin(
    request: Request,
    payload: TokenPayload | None = Depends(require_auth),
) -> TokenPayload:
    """
    FastAPI dependency that requires the caller to be an admin.

    Raises HTTP 403 if the authenticated user is not an admin.
    When AUTH_ENABLED=false, all requests are treated as admin.
    """
    if not AUTH_ENABLED:
        from deeptutor.services.auth import TokenPayload as TP

        return TP(username="local", role="admin", user_id="local-admin")

    if payload is None or payload.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    try:
        from deeptutor.services.admin_mfa import assert_admin_mfa

        assert_admin_mfa(request, payload.username)
    except HTTPException:
        raise
    except Exception:
        logger.debug("admin MFA gate skipped", exc_info=True)
    return payload


@router.get("/mfa/enroll")
async def mfa_enroll(
    request: Request,
    payload: TokenPayload = Depends(require_admin),
) -> dict:
    """Generate a TOTP secret for the current admin (pyotp)."""
    try:
        import pyotp
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="pyotp is not installed",
        ) from exc
    from deeptutor.services.admin_mfa import get_mfa_state, set_enrollment_secret

    secret = pyotp.random_base32()
    set_enrollment_secret(payload.username, secret)
    uri = pyotp.TOTP(secret).provisioning_uri(
        name=payload.username,
        issuer_name="DeepTutor",
    )
    return {
        "username": payload.username,
        "secret": secret,
        "otpauth_uri": uri,
        "enabled": bool(get_mfa_state(payload.username).get("enabled")),
    }


@router.post("/mfa/activate")
async def mfa_activate_endpoint(
    request: Request,
    body: MfaActivateRequest,
    payload: TokenPayload = Depends(require_admin),
) -> dict:
    """Verify a TOTP code and enable MFA for this admin account."""
    try:
        import pyotp
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="pyotp is not installed",
        ) from exc
    from deeptutor.services.admin_mfa import activate as mfa_activate_store
    from deeptutor.services.admin_mfa import get_mfa_state

    st = get_mfa_state(payload.username)
    secret = str(st.get("secret") or "")
    if not secret or not pyotp.TOTP(secret).verify(body.code.strip(), valid_window=1):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid TOTP code")
    mfa_activate_store(payload.username)
    return {"ok": True, "enabled": True}


# ---------------------------------------------------------------------------
# User TOTP MFA (any authenticated account, local JWT mode)
# ---------------------------------------------------------------------------


@router.get("/user/mfa/enroll")
async def user_mfa_enroll(
    payload: TokenPayload | None = Depends(require_auth),
) -> dict:
    """Generate a TOTP secret for the current user (not PocketBase)."""
    if not AUTH_ENABLED or POCKETBASE_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="User TOTP enrollment is only available in local JWT auth mode.",
        )
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )
    try:
        import pyotp
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="pyotp is not installed",
        ) from exc
    from deeptutor.services.user_totp import get_user_totp_state, set_user_enrollment_secret

    secret = pyotp.random_base32()
    set_user_enrollment_secret(payload.username, secret)
    uri = pyotp.TOTP(secret).provisioning_uri(
        name=payload.username,
        issuer_name="DeepTutor",
    )
    return {
        "username": payload.username,
        "secret": secret,
        "otpauth_uri": uri,
        "enabled": bool(get_user_totp_state(payload.username).get("enabled")),
    }


@router.post("/user/mfa/activate")
async def user_mfa_activate(
    body: MfaActivateRequest,
    payload: TokenPayload | None = Depends(require_auth),
) -> dict:
    """Verify a TOTP code and enable MFA for this user account."""
    if not AUTH_ENABLED or POCKETBASE_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="User TOTP is only available in local JWT auth mode.",
        )
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )
    try:
        import pyotp
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="pyotp is not installed",
        ) from exc
    from deeptutor.services.user_totp import activate_user_totp, get_user_totp_state

    st = get_user_totp_state(payload.username)
    secret = str(st.get("secret") or "")
    if not secret or not pyotp.TOTP(secret).verify(body.code.strip(), valid_window=1):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid TOTP code")
    activate_user_totp(payload.username)
    return {"ok": True, "enabled": True}


# ---------------------------------------------------------------------------
# Public endpoints (no auth required)
# ---------------------------------------------------------------------------


@router.get("/status", response_model=AuthStatusResponse)
async def auth_status(
    authorization: str | None = Header(default=None, alias="Authorization"),
    dt_token: str | None = Cookie(default=None),
) -> AuthStatusResponse:
    """Return whether auth is enabled and whether the current request is authenticated."""
    if not AUTH_ENABLED:
        return AuthStatusResponse(
            enabled=False,
            authenticated=True,
            user_id="local-admin",
            username="local",
            role="admin",
            is_admin=True,
        )

    token = _extract_token(authorization, dt_token)
    payload = decode_token(token) if token else None
    return AuthStatusResponse(
        enabled=True,
        authenticated=payload is not None,
        user_id=payload.user_id if payload else None,
        username=payload.username if payload else None,
        role=payload.role if payload else None,
        is_admin=payload.role == "admin" if payload else False,
    )


@router.post("/login")
async def login(body: LoginRequest, response: Response) -> dict:
    """Validate credentials and set a JWT cookie."""
    if not AUTH_ENABLED:
        return {"ok": True, "message": "Auth is disabled — no login required."}

    from deeptutor.services.login_lockout import (
        clear_failed_attempts,
        is_locked,
        record_failed_attempt,
        user_login_attempt_lock,
    )

    with user_login_attempt_lock(body.username):
        locked, locked_until = is_locked(body.username)
        if locked:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=(
                    "Too many failed sign-in attempts. Try again later"
                    + (f" (until {locked_until})" if locked_until else "")
                    + "."
                ),
            )

        if POCKETBASE_ENABLED:
            # PocketBase mode: email = username field for backwards-compat with the
            # existing LoginRequest schema; users can pass their email as "username".
            pb_result = authenticate_pb(body.username, body.password)
            if not pb_result:
                record_failed_attempt(body.username)
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Incorrect email or password",
                )
            payload, pb_token = pb_result
            clear_failed_attempts(body.username)
            response.set_cookie(
                key=_COOKIE_NAME,
                value=pb_token,
                httponly=True,
                samesite=_SAMESITE,
                max_age=_session_cookie_max_seconds(),
                secure=_SECURE,
            )
            logger.info(f"User '{payload.username}' logged in via PocketBase (role={payload.role!r})")
            return {
                "ok": True,
                "user_id": payload.user_id,
                "username": payload.username,
                "role": payload.role,
                "is_admin": payload.role == "admin",
                "access_token": pb_token,
            }

        # Standard JWT + bcrypt mode
        result = authenticate(body.username, body.password)
        if not result:
            record_failed_attempt(body.username)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
            )

        clear_failed_attempts(result.username)

        token = create_token(result.username, result.role, result.user_id)
        response.set_cookie(
            key=_COOKIE_NAME,
            value=token,
            httponly=True,
            samesite=_SAMESITE,
            max_age=_session_cookie_max_seconds(),
            secure=_SECURE,
        )

        logger.info(f"User '{result.username}' logged in (role={result.role!r})")
        return {
            "ok": True,
            "user_id": result.user_id,
            "username": result.username,
            "role": result.role,
            "is_admin": result.role == "admin",
            "access_token": token,
        }


@router.post("/logout")
async def logout(response: Response) -> dict:
    """Clear the JWT cookie."""
    response.delete_cookie(key=_COOKIE_NAME, samesite=_SAMESITE)
    return {"ok": True}


@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest) -> dict:
    """
    Bootstrap-only registration.

    Public endpoint that creates the *first* admin account when the user store
    is empty. Once an admin exists, this endpoint is closed; further accounts
    must be created by an admin via ``POST /api/v1/auth/users``.

    Only available when AUTH_ENABLED=true.
    """
    if not AUTH_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Auth is disabled — registration is not available.",
        )

    from deeptutor.services.password_policy import password_is_pwned

    if await password_is_pwned(body.password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This password appears in known data breaches. Choose a different password.",
        )

    if POCKETBASE_ENABLED:
        # PocketBase deployments are documented as single-user. Keep registration
        # closed and require admins to provision users in the PocketBase admin UI.
        if not is_first_user():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Self-registration is closed. Ask an administrator to create your account.",
            )
        result = register_pb(username=body.username, email=body.username, password=body.password)
        if not result:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Registration failed — username or email may already be taken.",
            )
        logger.info(f"First user registered via PocketBase: '{body.username}'")
        return {
            "ok": True,
            "user_id": result.get("id", ""),
            "username": body.username,
            "role": "student",
            "is_first_user": True,
            "is_admin": False,
        }

    # Standard mode — atomically create the first admin (closes registration).
    from deeptutor.multi_user.identity import BootstrapRegisterError, bootstrap_register
    from deeptutor.services.auth import hash_password

    try:
        record = bootstrap_register(body.username, hash_password(body.password))
    except BootstrapRegisterError as exc:
        code = str(exc)
        if code == "bootstrap_closed":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Self-registration is closed. Ask an administrator to create your account.",
            ) from exc
        if code == "username_taken":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Username already taken",
            ) from exc
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Registration failed",
        ) from exc

    role = str(record.get("role") or "admin")
    user_id = str(record.get("id") or "")
    logger.info(f"First user (admin) registered: '{body.username}'")
    return {
        "ok": True,
        "user_id": user_id,
        "username": body.username,
        "role": role,
        "is_first_user": True,
        "is_admin": role == "admin",
    }


@router.get("/is_first_user")
async def check_is_first_user() -> dict:
    """Return whether the user store is empty (used by the register UI)."""
    return {"is_first_user": is_first_user() if AUTH_ENABLED else False}


def _firebase_project_id() -> str:
    return os.getenv("FIREBASE_PROJECT_ID", "").strip()


def _verify_firebase_id_token(id_token: str) -> dict[str, object]:
    """Decode and verify a Firebase Web ID token; returns claims dict."""
    try:
        import firebase_admin
        from firebase_admin import auth as fb_auth
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="firebase-admin is not installed. Install server extras: pip install -e '.[server]'",
        ) from exc

    project_id = _firebase_project_id()
    if not project_id:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Set FIREBASE_PROJECT_ID for Firebase sign-in.",
        )

    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={"projectId": project_id})

    try:
        return dict(fb_auth.verify_id_token(id_token, check_revoked=False))
    except Exception as exc:
        logger.warning("Firebase ID token verification failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase ID token",
        ) from exc


class FirebaseSignInRequest(BaseModel):
    """Firebase Web SDK ID token from ``getIdToken()``."""

    id_token: str = Field(min_length=80, max_length=16_384)


@router.post("/firebase")
async def firebase_sign_in(body: FirebaseSignInRequest, response: Response) -> dict:
    """Verify a Firebase ID token and issue the standard ``dt_token`` session cookie.

    When ``AUTH_ENABLED=true`` and no local user exists yet, the first Firebase
    sign-in creates an account using the verified email as username (same rules
    as email/password first registration).
    """
    if not AUTH_ENABLED:
        return {"ok": True, "message": "Auth is disabled — no session cookie set."}

    if POCKETBASE_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Firebase sign-in is not wired for PocketBase mode.",
        )

    claims = _verify_firebase_id_token(body.id_token)
    email = str(claims.get("email") or "").strip().lower()
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Firebase token has no email claim",
        )

    match: dict | None = None
    for row in list_users():
        if (row.get("username") or "").strip().lower() == email:
            match = row
            break

    if not match:
        if not is_first_user():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "No local account for this email. Ask an admin to create one, "
                    "or use email registration when you are the first user."
                ),
            )
        temp_password = secrets.token_urlsafe(24)
        add_user(email, temp_password)
        for row in list_users():
            if (row.get("username") or "").strip().lower() == email:
                match = row
                break
        if not match:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to provision first user from Firebase",
            )
        logger.info("First user provisioned via Firebase: %r", email)

    _reject_disabled_user(match)
    username = str(match.get("username") or email)
    role = str(match.get("role") or "student")
    user_id = str(match.get("id") or "")
    jwt_token = create_token(username, role, user_id)
    response.set_cookie(
        key=_COOKIE_NAME,
        value=jwt_token,
        httponly=True,
        samesite=_SAMESITE,
        max_age=_session_cookie_max_seconds(),
        secure=_SECURE,
    )
    logger.info("User %r signed in via Firebase ID token", username)
    return {
        "ok": True,
        "user_id": user_id,
        "username": username,
        "role": role,
        "is_admin": role == "admin",
    }


class GoogleOAuthExchangeRequest(BaseModel):
    """Authorization code from Google OAuth redirect (PKCE optional, not enforced here)."""

    code: str = Field(min_length=8, max_length=4096)
    state: str | None = Field(default=None, max_length=2048)


def _oauth_state_secret() -> str:
    from deeptutor.services.auth import AUTH_SECRET

    if AUTH_SECRET:
        return AUTH_SECRET
    from deeptutor.multi_user.identity import load_or_create_auth_secret

    return load_or_create_auth_secret()


def issue_google_oauth_state() -> str:
    """Return an HMAC-signed OAuth state nonce (binds callback to our auth secret)."""
    nonce = secrets.token_urlsafe(16)
    sig = hmac.new(
        _oauth_state_secret().encode(),
        nonce.encode(),
        hashlib.sha256,
    ).hexdigest()[:32]
    return f"{nonce}.{sig}"


def verify_google_oauth_state(state: str | None) -> bool:
    if not state or "." not in state:
        return False
    nonce, sig = state.rsplit(".", 1)
    if not nonce or not sig:
        return False
    expected = hmac.new(
        _oauth_state_secret().encode(),
        nonce.encode(),
        hashlib.sha256,
    ).hexdigest()[:32]
    return hmac.compare_digest(sig, expected)


@router.get("/oauth/google/state")
async def google_oauth_state() -> dict:
    """Issue a server-signed OAuth ``state`` for the Google redirect (CSRF protection)."""
    if not AUTH_ENABLED:
        return {"state": ""}
    return {"state": issue_google_oauth_state()}


@router.post("/oauth/google/callback")
async def google_oauth_exchange(
    body: GoogleOAuthExchangeRequest,
    response: Response,
) -> dict:
    """Exchange a Google auth ``code`` for a DeepTutor session cookie.

    Requires ``GOOGLE_OAUTH_CLIENT_ID``, ``GOOGLE_OAUTH_CLIENT_SECRET``, and
    ``GOOGLE_OAUTH_REDIRECT_URI`` in the environment. The Google account email
    must match an existing local ``username`` (typically the same email string),
    unless the user store is empty — then the first Google sign-in provisions
    an admin account (same rule as Firebase sign-in).
    """
    if not AUTH_ENABLED:
        return {"ok": True, "message": "Auth is disabled — no session cookie set."}

    if POCKETBASE_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Google web OAuth is not wired for PocketBase mode; use PocketBase auth.",
        )

    if not verify_google_oauth_state(body.state):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or missing OAuth state",
        )

    client_id = os.getenv("GOOGLE_OAUTH_CLIENT_ID", "").strip()
    client_secret = os.getenv("GOOGLE_OAUTH_CLIENT_SECRET", "").strip()
    redirect_uri = os.getenv("GOOGLE_OAUTH_REDIRECT_URI", "").strip()
    if not client_id or not client_secret or not redirect_uri:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail=(
                "Google OAuth not configured. Set GOOGLE_OAUTH_CLIENT_ID, "
                "GOOGLE_OAUTH_CLIENT_SECRET, and GOOGLE_OAUTH_REDIRECT_URI in .env"
            ),
        )

    import httpx

    async with httpx.AsyncClient(timeout=30.0) as client:
        token_res = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "grant_type": "authorization_code",
                "code": body.code,
                "client_id": client_id,
                "client_secret": client_secret,
                "redirect_uri": redirect_uri,
            },
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        if token_res.status_code != 200:
            logger.warning("Google token exchange failed: %s", token_res.text[:500])
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Google token exchange failed",
            )
        tokens = token_res.json()
        access = (tokens.get("access_token") or "").strip()
        if not access:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Google response missing access_token",
            )

        ui = await client.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {access}"},
        )
        if ui.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Google userinfo request failed",
            )
        email = (ui.json().get("email") or "").strip().lower()
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Google account has no email",
            )

    match: dict | None = None
    for row in list_users():
        un = (row.get("username") or "").strip().lower()
        if un == email:
            match = row
            break
    if not match:
        if not is_first_user():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "No local account matches this Google email. "
                    "Use an admin-created username equal to your Google email, or register first."
                ),
            )
        temp_password = secrets.token_urlsafe(24)
        add_user(email, temp_password)
        for row in list_users():
            un = (row.get("username") or "").strip().lower()
            if un == email:
                match = row
                break
        if not match:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to provision first user from Google OAuth",
            )
        logger.info("First user provisioned via Google OAuth: %r", email)

    _reject_disabled_user(match)
    username = str(match.get("username") or "")
    role = str(match.get("role") or "student")
    user_id = str(match.get("id") or "")
    jwt_token = create_token(username, role, user_id)
    response.set_cookie(
        key=_COOKIE_NAME,
        value=jwt_token,
        httponly=True,
        samesite=_SAMESITE,
        max_age=_session_cookie_max_seconds(),
        secure=_SECURE,
    )
    logger.info("User %r signed in via Google OAuth", username)
    return {
        "ok": True,
        "user_id": user_id,
        "username": username,
        "role": role,
        "is_admin": role == "admin",
    }


# ---------------------------------------------------------------------------
# Admin-only endpoints
# ---------------------------------------------------------------------------


@router.get("/users", response_model=list[UserInfo])
async def get_users(_: TokenPayload = Depends(require_admin)) -> list[UserInfo]:
    """List all registered users. Requires admin role."""
    return [UserInfo(**u) for u in list_users()]


@router.post("/users", status_code=status.HTTP_201_CREATED)
async def admin_create_user(
    body: RegisterRequest,
    current: TokenPayload = Depends(require_admin),
) -> dict:
    """Admin-only: create a new user account.

    Replaces the public ``/register`` flow once the first admin exists. The
    new account defaults to role ``student``; admins can change it later via
    ``PUT /users/{username}/role``.
    """
    if not AUTH_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Auth is disabled — user creation is not available.",
        )

    from deeptutor.services.password_policy import password_is_pwned

    if await password_is_pwned(body.password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This password appears in known data breaches. Choose a different password.",
        )

    if POCKETBASE_ENABLED:
        result = register_pb(username=body.username, email=body.username, password=body.password)
        if not result:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Failed to create user — username may already be taken.",
            )
        logger.info(
            f"Admin '{current.username if current else 'local'}' created PocketBase user "
            f"'{body.username}'"
        )
        return {
            "ok": True,
            "user_id": result.get("id", ""),
            "username": body.username,
            "role": "student",
            "is_admin": False,
        }

    existing = {u["username"] for u in list_users()}
    if body.username in existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username already taken",
        )

    add_user(body.username, body.password)
    user_id = ""
    role = "student"
    for item in list_users():
        if item.get("username") == body.username:
            user_id = str(item.get("id") or "")
            role = str(item.get("role") or "student")
            break
    logger.info(
        f"Admin '{current.username if current else 'local'}' created user '{body.username}' "
        f"(role={role!r})"
    )
    return {
        "ok": True,
        "user_id": user_id,
        "username": body.username,
        "role": role,
        "is_admin": role == "admin",
    }


@router.delete("/users/{username}", status_code=status.HTTP_200_OK)
async def remove_user(
    username: str,
    current: TokenPayload = Depends(require_admin),
) -> dict:
    """Delete a user. Admins cannot delete their own account."""
    if current and username == current.username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot delete your own account",
        )

    removed = delete_user(username)
    if not removed:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    logger.info(f"Admin '{current.username if current else 'local'}' deleted user '{username}'")
    return {"ok": True}


@router.put("/users/{username}/role", status_code=status.HTTP_200_OK)
async def update_user_role(
    username: str,
    body: SetRoleRequest,
    current: TokenPayload = Depends(require_admin),
) -> dict:
    """Change a user's role. Admins cannot change their own role."""
    if current and username == current.username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You cannot change your own role",
        )

    updated = set_role(username, body.role)
    if not updated:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    logger.info(
        f"Admin '{current.username if current else 'local'}' set '{username}' role to {body.role!r}"
    )
    return {"ok": True, "username": username, "role": body.role}
