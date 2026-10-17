from datetime import date
from decimal import Decimal
import json
from uuid import UUID
from fastapi import APIRouter, Depends, Query, Response
from fastapi.responses import JSONResponse
from app.core.database import transaction
from app.shared.access import require_user, child_access
from app.shared.errors import ApiError
from app.features.growth.schemas import SaveDay, ChildInput, CalendarDate
from app.features.growth import service as s

router = APIRouter(prefix='/api/v1', tags=['Growth'])


class GrowthJSONResponse(JSONResponse):
    """Serialize large histories once instead of recursively encoding every field."""
    def render(self, content):
        def encode(value):
            if isinstance(value, Decimal): return float(value)
            if isinstance(value, (date, UUID)): return value.isoformat() if isinstance(value,date) else str(value)
            raise TypeError(f'Unsupported response value: {type(value).__name__}')
        return json.dumps(content,ensure_ascii=False,allow_nan=False,separators=(',',':'),default=encode).encode('utf-8')


@router.get('/children')
def children(user=Depends(require_user)):
    with transaction() as db:
        rows = db.execute('''SELECT c.* FROM child.children c WHERE c.deleted_at IS NULL AND
            (c.owner_user_id=%s OR EXISTS(SELECT 1 FROM child.child_members m
            JOIN child.child_member_permissions p ON p.member_id=m.id WHERE m.child_id=c.id
            AND m.user_id=%s AND m.status='active' AND p.data_scope='growth'
            AND p.access_level IN ('view','edit'))) ORDER BY c.created_at,c.id''',
            (user['id'], user['id'])).fetchall()
        return {'children': [s.child_public(child_access(db, c['id'], user['id'])) for c in rows]}


@router.post('/children', status_code=201)
def create_child(data: ChildInput, user=Depends(require_user)):
    s.validate_day(data.dateOfBirth, date.min)
    with transaction() as db:
        row = db.execute('''INSERT INTO child.children
            (owner_user_id,full_name,date_of_birth,gender,gestational_weeks,birth_weight_kg)
            VALUES (%s,%s,%s,%s,%s,%s) RETURNING *''', (user['id'], data.fullName,
            data.dateOfBirth,data.gender,data.gestationalWeeks,data.birthWeightKg)).fetchone()
        row['growthAccess'] = 'edit'
        return s.child_public(row)


@router.get('/children/{child_id}')
def get_child(child_id: UUID, user=Depends(require_user)):
    with transaction() as db:
        return s.child_public(child_access(db, child_id, user['id']))


@router.put('/children/{child_id}')
def update_child(child_id: UUID, data: ChildInput, user=Depends(require_user)):
    s.validate_day(data.dateOfBirth, date.min)
    with transaction() as db:
        child = child_access(db, child_id, user['id'], lock=True)
        if child['owner_user_id'] != user['id']:
            raise ApiError(403, 'PROFILE_WRITE_FORBIDDEN')
        if db.execute('''SELECT 1 FROM growth.growth_measurements WHERE child_id=%s
            AND deleted_at IS NULL AND measured_at<%s LIMIT 1''', (child_id,data.dateOfBirth)).fetchone():
            raise ApiError(422, 'VALIDATION_ERROR', {'dateOfBirth': 'Birth date is after an existing measurement'})
        row = db.execute('''UPDATE child.children SET full_name=%s,date_of_birth=%s,gender=%s,
            gestational_weeks=%s,birth_weight_kg=%s,updated_at=now() WHERE id=%s RETURNING *''',
            (data.fullName,data.dateOfBirth,data.gender,data.gestationalWeeks,data.birthWeightKg,child_id)).fetchone()
        db.execute('''UPDATE growth.growth_measurements SET age_in_days=measured_at-%s,
            updated_at=now(),updated_by=%s WHERE child_id=%s AND deleted_at IS NULL''',
            (data.dateOfBirth,user['id'],child_id))
        row['growthAccess'] = 'edit'
        return s.child_public(row)


@router.get('/children/{child_id}/growth')
def get_growth(child_id: UUID, start: CalendarDate | None = Query(None, alias='from'),
               end: CalendarDate | None = Query(None, alias='to'), user=Depends(require_user)):
    if start and end and start > end:
        raise ApiError(422, 'VALIDATION_ERROR', {'to': 'Must be on or after from'})
    with transaction() as db:
        db.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY')
        return GrowthJSONResponse(s.read_growth(db, child_access(db, child_id, user['id']), start, end),
                                  headers={'Cache-Control':'no-store'})


@router.put('/children/{child_id}/growth/days/{day}')
def put_growth(child_id: UUID, day: CalendarDate, data: SaveDay, user=Depends(require_user)):
    with transaction() as db:
        return s.save_day(db, child_access(db, child_id, user['id'], True), day, data, user['id'])


@router.delete('/children/{child_id}/growth/measurements/{measurement_id}', status_code=204)
def delete_growth(child_id: UUID, measurement_id: UUID, user=Depends(require_user)):
    with transaction() as db:
        child_access(db, child_id, user['id'], True)
        row = db.execute('SELECT id FROM growth.growth_measurements WHERE id=%s AND child_id=%s',
                         (measurement_id, child_id)).fetchone()
        if not row:
            raise ApiError(404, 'MEASUREMENT_NOT_FOUND')
        db.execute('''UPDATE growth.growth_measurements SET deleted_at=now(),deleted_by=%s,
            updated_by=%s,updated_at=now() WHERE id=%s AND deleted_at IS NULL''',
            (user['id'],user['id'],measurement_id))
    return Response(status_code=204)
