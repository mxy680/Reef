import jwt
from fastapi import Depends, HTTPException, WebSocket, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import settings

security = HTTPBearer()


class AuthenticatedUser:
    def __init__(self, sub: str, email: str | None = None, role: str | None = None):
        self.id = sub
        self.email = email
        self.role = role


def verify_token(token: str) -> AuthenticatedUser:
    try:
        payload = jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
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
