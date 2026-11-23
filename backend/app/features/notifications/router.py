from typing import Literal
from datetime import date
from uuid import UUID
from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, Field
from app.core.database import get_db
from app.features.auth.dependencies import current_user_id, token_identity
from app.core.config import settings
from app.shared.access import require_child_access
from . import service
from .rules import age_based_interval
from .service import _age_months
from datetime import datetime, timezone

router = APIRouter(prefix='/api/v1/notifications', tags=['mobile: notifications'])

class ReadBody(BaseModel):
    ids: list[UUID] = Field(default_factory=list, max_length=200)
    all: bool = False

class Preferences(BaseModel):
    push_enabled: bool = True
    timezone_offset: int = Field(default=420, ge=-720, le=840)
    send_hour: int = Field(default=8, ge=0, le=23)
    send_minute: int = Field(default=0, ge=0, le=59)
    growth_interval_days: int = Field(default=30, ge=7, le=365)

class Device(BaseModel):
    token: str = Field(min_length=20, max_length=4096)
    platform: Literal['android','ios']

class GrowthSetting(BaseModel):
    enabled: bool = True
    snoozed_until: date | None = None
    mode: Literal['age_based', 'custom'] = 'age_based'
    interval_days: int | None = Field(default=None, ge=15, le=180)

@router.get('')
def listing(offset: int = Query(0,ge=0), limit: int = Query(50,ge=1,le=100), user=Depends(current_user_id), conn=Depends(get_db)):
    with conn:
        service.generate(conn,user)
        return service.inbox(conn,user,offset,limit)

@router.post('/read')
def read(body: ReadBody, user=Depends(current_user_id), conn=Depends(get_db)):
    with conn,conn.cursor() as cur:
        cur.execute(f"""UPDATE notification.notifications n SET read_at=coalesce(read_at,now())
          WHERE n.user_id=%s AND (%s OR n.id=ANY(%s::uuid[])) AND {service.ACCESS}""",
          (str(user),body.all,[str(i) for i in body.ids]))
    return {'ok':True}

@router.get('/preferences')
def preferences(user=Depends(current_user_id),conn=Depends(get_db)):
    with conn,conn.cursor() as cur:
        cur.execute('ALTER TABLE notification.preferences ADD COLUMN IF NOT EXISTS send_minute integer NOT NULL DEFAULT 0 CHECK(send_minute BETWEEN 0 AND 59)')
        cur.execute('SELECT * FROM notification.preferences WHERE user_id=%s',(str(user),))
        return cur.fetchone() or Preferences().model_dump()

@router.put('/preferences')
def save_preferences(body: Preferences,user=Depends(current_user_id),conn=Depends(get_db)):
    with conn,conn.cursor() as cur:
        cur.execute('ALTER TABLE notification.preferences ADD COLUMN IF NOT EXISTS send_minute integer NOT NULL DEFAULT 0 CHECK(send_minute BETWEEN 0 AND 59)')
        cur.execute("""INSERT INTO notification.preferences(user_id,push_enabled,timezone_offset,send_hour,send_minute,growth_interval_days)
          VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT(user_id) DO UPDATE SET push_enabled=excluded.push_enabled,
          timezone_offset=excluded.timezone_offset,send_hour=excluded.send_hour,send_minute=excluded.send_minute,growth_interval_days=excluded.growth_interval_days""",
          (str(user),body.push_enabled,body.timezone_offset,body.send_hour,body.send_minute,body.growth_interval_days))
    return body

@router.get('/growth/{child_id}')
def growth_settings_all(child_id: UUID, user=Depends(current_user_id), conn=Depends(get_db)):
    """Lấy cài đặt nhắc cho cả 3 chỉ số của một trẻ, kèm chu kỳ mặc định theo tuổi."""
    require_child_access(conn, child_id, user, 'growth', 'view')
    with conn.cursor() as cur:
        cur.execute('SELECT date_of_birth FROM child.children WHERE id=%s AND deleted_at IS NULL', (str(child_id),))
        row = cur.fetchone()
        dob = row['date_of_birth'] if row else None
        age_months = _age_months(dob) if dob else 0

        result = {}
        for metric in ('weight', 'height', 'head_circumference'):
            cur.execute('SELECT * FROM growth.reminder_settings WHERE child_id=%s AND user_id=%s AND metric=%s',
                        (str(child_id), str(user), metric))
            setting = cur.fetchone() or {}
            default_interval = age_based_interval(metric, age_months)
            result[metric] = {
                'enabled': setting.get('enabled', True),
                'mode': setting.get('mode', 'age_based'),
                'interval_days': setting.get('interval_days'),
                'snoozed_until': setting.get('snoozed_until'),
                'age_based_interval': default_interval,  # thông tin tham khảo
            }
    return {'age_months': age_months, 'metrics': result}


@router.put('/growth/{child_id}/{metric}')
def growth_setting(child_id: UUID, metric: Literal['weight','height','head_circumference'], body: GrowthSetting, user=Depends(current_user_id), conn=Depends(get_db)):
    require_child_access(conn, child_id, user, 'growth', 'edit')
    with conn, conn.cursor() as cur:
        cur.execute("""INSERT INTO growth.reminder_settings(child_id,user_id,metric,enabled,snoozed_until,mode,interval_days)
          VALUES (%s,%s,%s,%s,%s,%s,%s) ON CONFLICT(child_id,user_id,metric) DO UPDATE
          SET enabled=excluded.enabled,snoozed_until=excluded.snoozed_until,
              mode=excluded.mode,interval_days=excluded.interval_days,updated_at=now()""",
          (str(child_id), str(user), metric, body.enabled, body.snoozed_until, body.mode, body.interval_days))
    return {'ok': True}

@router.put('/device')
def device(body: Device,request: Request,user=Depends(current_user_id),conn=Depends(get_db)):
    _,sid=token_identity(request,settings.auth_audience)
    with conn,conn.cursor() as cur:
        cur.execute("""INSERT INTO account.device_tokens(user_id,session_id,fcm_token,platform)
          VALUES (%s,%s,%s,%s) ON CONFLICT(fcm_token) DO UPDATE SET user_id=excluded.user_id,
          session_id=excluded.session_id,platform=excluded.platform,is_active=true,updated_at=now()""",
          (str(user),str(sid),body.token,body.platform))
    return {'ok':True}

@router.delete('/device')
def remove_device(body: Device,user=Depends(current_user_id),conn=Depends(get_db)):
    with conn,conn.cursor() as cur:
        cur.execute('UPDATE account.device_tokens SET is_active=false WHERE user_id=%s AND fcm_token=%s',(str(user),body.token))
    return {'ok':True}
