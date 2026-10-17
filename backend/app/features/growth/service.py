from datetime import datetime, timezone, timedelta
from decimal import Decimal, ROUND_HALF_UP
from app.shared.errors import ApiError


def today():
    return datetime.now(timezone(timedelta(hours=7))).date()


def validate_day(day, birth):
    if day < birth or day > today():
        raise ApiError(422, 'VALIDATION_ERROR', {'date': 'Date must be between birth date and today'})


def child_public(c):
    return {'id': c['id'], 'fullName': c['full_name'], 'dateOfBirth': c['date_of_birth'],
            'gender': c['gender'], 'growthAccess': c['growthAccess']}


def measurement_public(r):
    return {'id': r['id'], 'metric': r['metric'], 'value': float(r['value']),
            'unit': 'kg' if r['metric'] == 'weight' else 'cm',
            'measurePosition': r['measure_position'], 'measuredAt': r['measured_at'],
            'ageInDays': r['age_in_days'], 'note': r['note'],
            'createdAt': r['created_at'].astimezone(timezone.utc),
            'updatedAt': r['updated_at'].astimezone(timezone.utc)}


def bmi(weight, height):
    return float((Decimal(str(weight)) / (Decimal(str(height)) / 100) ** 2)
                 .quantize(Decimal('.01'), rounding=ROUND_HALF_UP))


def day_result(day, records):
    by_metric = {r['metric']: r for r in records}
    w, h = by_metric.get('weight'), by_metric.get('height')
    point = None if not w or not h else {
        'measuredAt': day, 'value': bmi(w['value'], h['value']), 'unit': 'kg/m2',
        'weightMeasurementId': w['id'], 'heightMeasurementId': h['id']}
    return {'measuredAt': day, 'measurements': [measurement_public(r) for r in records], 'bmi': point}


def read_growth(db, child, start=None, end=None):
    rows = db.execute('''SELECT * FROM growth.growth_measurements
        WHERE child_id=%s AND deleted_at IS NULL
        AND (%s::date IS NULL OR measured_at >= %s)
        AND (%s::date IS NULL OR measured_at <= %s)
        ORDER BY measured_at, metric''',
        (child['id'],start,start,end,end)).fetchall()
    grouped = {}
    for row in rows:
        grouped.setdefault(row['measured_at'], []).append(row)
    days = [day_result(day, items) for day, items in grouped.items()]
    summary = dict.fromkeys(['weight', 'height', 'headCircumference', 'bmi'])
    for day in days:
        for m in day['measurements']:
            summary['headCircumference' if m['metric'] == 'head_circumference' else m['metric']] = m
        if day['bmi']:
            summary['bmi'] = day['bmi']
    if start or end:
        # Summary is independent of the date filter. Avoid loading five years of
        # measurements just to display a narrow chart range.
        summary = dict.fromkeys(['weight','height','headCircumference','bmi'])
        latest = db.execute('''SELECT DISTINCT ON (metric) * FROM growth.growth_measurements
            WHERE child_id=%s AND deleted_at IS NULL ORDER BY metric,measured_at DESC''',
            (child['id'],)).fetchall()
        for r in latest:
            summary['headCircumference' if r['metric']=='head_circumference' else r['metric']] = measurement_public(r)
        pair = db.execute('''SELECT w.measured_at,w.id AS wid,h.id AS hid,w.value AS weight,h.value AS height
            FROM growth.growth_measurements w JOIN growth.growth_measurements h
            ON h.child_id=w.child_id AND h.measured_at=w.measured_at AND h.metric='height'
            AND h.deleted_at IS NULL WHERE w.child_id=%s AND w.metric='weight'
            AND w.deleted_at IS NULL ORDER BY w.measured_at DESC LIMIT 1''',(child['id'],)).fetchone()
        if pair:
            summary['bmi'] = {'measuredAt':pair['measured_at'],'value':bmi(pair['weight'],pair['height']),
                'unit':'kg/m2','weightMeasurementId':pair['wid'],'heightMeasurementId':pair['hid']}
    return {'child': child_public(child), 'range': {'from': start, 'to': end},
            'days': [d for d in days if (not start or d['measuredAt'] >= start)
                     and (not end or d['measuredAt'] <= end)], 'summary': summary}


def save_day(db, child, day, data, user_id):
    validate_day(day, child['date_of_birth'])
    values = [('weightKg', 'weight'), ('height', 'height'), ('headCircumferenceCm', 'head_circumference')]
    for field, metric in values:
        if field not in data.model_fields_set:
            continue
        item = getattr(data, field)
        value = item.value if metric == 'height' else item
        position = item.measurePosition if metric == 'height' else None
        note_set = 'note' in data.model_fields_set
        db.execute('''INSERT INTO growth.growth_measurements
            (child_id,metric,value,measure_position,measured_at,age_in_days,note,created_by,updated_by)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (child_id,metric,measured_at) WHERE deleted_at IS NULL
            DO UPDATE SET value=excluded.value,measure_position=excluded.measure_position,
            age_in_days=excluded.age_in_days,note=CASE WHEN %s THEN excluded.note
            ELSE growth.growth_measurements.note END,updated_by=excluded.updated_by,updated_at=now()''',
            (child['id'], metric, value, position, day, (day-child['date_of_birth']).days,
             data.note, user_id, user_id, note_set))
    records = db.execute('''SELECT * FROM growth.growth_measurements
        WHERE child_id=%s AND measured_at=%s AND deleted_at IS NULL ORDER BY metric''',
        (child['id'], day)).fetchall()
    return day_result(day, records)
