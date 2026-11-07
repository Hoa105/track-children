import datetime as dt

from fastapi import APIRouter, Depends, HTTPException, Query
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.features.admin_dashboard import service
from app.features.auth.dependencies import require_admin

admin_router = APIRouter(prefix="/admin", tags=["admin: dashboard"])


@admin_router.get("/dashboard")
def admin_dashboard(
    date_from: dt.date | None = Query(None, alias="from"),
    date_to: dt.date | None = Query(None, alias="to"),
    _: str = Depends(require_admin("report.read")),
    conn: Connection = Depends(get_db),
):
    """Số liệu tổng quan; from/to (YYYY-MM-DD, tính cả 2 đầu) lọc phần "mới trong khoảng"."""
    if date_from and date_to and date_from > date_to:
        raise HTTPException(422, "from phải trước hoặc bằng to")
    return service.dashboard(conn, date_from, date_to)
