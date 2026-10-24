"""Local child-profile helper for authenticated parents; never provisions accounts."""

import datetime as dt
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from psycopg2 import errors
from psycopg2.extensions import connection as Connection
from pydantic import Field

from app.core.config import settings
from app.core.database import get_db
from app.features.auth.dependencies import require_user
from app.features.vaccination.schema import CamelModel

router = APIRouter(prefix="/dev", tags=["dev"])


class DevParent(CamelModel):
    id: UUID
    email: str = Field(min_length=3, max_length=255)
    full_name: str = Field(min_length=1, max_length=150)


class DevChild(CamelModel):
    id: UUID
    full_name: str = Field(min_length=1, max_length=150)
    date_of_birth: dt.date
    gender: Literal["male", "female"]


class DevProfile(CamelModel):
    parent: DevParent
    child: DevChild


def _require_dev() -> None:
    if not settings.dev_auth or settings.app_env != "local":
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Not Found")


@router.put(
    "/profiles",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(_require_dev)],
)
def put_profile(
    body: DevProfile,
    user: dict = Depends(require_user),
    conn: Connection = Depends(get_db),
) -> None:
    """Tạo (hoặc cập nhật tên / ngày sinh) phụ huynh + bé theo uuid do mobile sinh."""
    parent, child = body.parent, body.child
    if parent.id != UUID(str(user["id"])):
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Profile must belong to authenticated user"
        )
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO child.children (id, owner_user_id, full_name, date_of_birth, gender)
                VALUES (%(id)s, %(owner)s, %(name)s, %(dob)s, %(gender)s)
                ON CONFLICT (id) DO UPDATE SET
                  full_name = EXCLUDED.full_name, date_of_birth = EXCLUDED.date_of_birth,
                  gender = EXCLUDED.gender
                WHERE child.children.owner_user_id = EXCLUDED.owner_user_id
                RETURNING id
                """,
                {
                    "id": str(child.id),
                    "owner": str(parent.id),
                    "name": child.full_name,
                    "dob": child.date_of_birth,
                    "gender": child.gender,
                },
            )
            if cur.fetchone() is None:
                raise HTTPException(
                    status.HTTP_403_FORBIDDEN, "Hồ sơ trẻ thuộc tài khoản khác"
                )
    except errors.UniqueViolation:
        raise HTTPException(
            status.HTTP_409_CONFLICT, "Email đã thuộc tài khoản khác"
        ) from None
