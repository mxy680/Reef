import httpx
import jwt
from fastapi import Depends, HTTPException, WebSocket, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient

from app.config import settings

security = HTTPBearer()

# JWKS client — caches keys automatically
_jwks_client: PyJWKClient | None = None


def _get_jwks_client() -> PyJWKClient:
    global _jwks_client
    if _jwks_client is None:
        jwks_url = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
        _jwks_client = PyJWKClient(jwks_url, cache_keys=True, lifespan=3600)
    return _jwks_client


class AuthenticatedUser:
    def __init__(self, sub: str, email: str | None = None, role: str | None = None):
        self.id = sub
        self.email = email
        self.role = role


def verify_token(token: str) -> AuthenticatedUser:
    try:
        client = _get_jwks_client()
        signing_key = client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience="authenticated",
        )
        return AuthenticatedUser(
            sub=payload["sub"],
            email=payload.get("email"),
            role=payload.get("role"),
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired"
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid token: {e}"
        )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> AuthenticatedUser:
    # Dev bypass: accept "dev" token in development mode
    if (
        settings.debug
        and settings.environment == "development"
        and credentials.credentials == "dev"
    ):
        return AuthenticatedUser(sub="dev-user", email="dev@localhost", role="authenticated")
    return verify_token(credentials.credentials)


async def ws_authenticate(websocket: WebSocket) -> AuthenticatedUser | None:
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4001, reason="Missing token")
        return None
    try:
        return verify_token(token)
    except HTTPException:
        await websocket.close(code=4003, reason="Invalid token")
        return None
