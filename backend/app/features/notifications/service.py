"""Durable inbox. Access is checked again when reading and delivering."""
import json
from datetime import datetime, timedelta, timezone

from app.features.assessment import service as assessment
from .rules import assessment_stage, growth_due, effective_interval


ACCESS = """(n.child_id IS NULL OR EXISTS (
 SELECT 1 FROM child.children c WHERE c.id=n.child_id AND c.deleted_at IS NULL
 AND (c.owner_user_id=n.user_id OR EXISTS (
 SELECT 1 FROM child.child_members m JOIN child.child_member_permissions p ON p.member_id=m.id
 WHERE m.child_id=c.id AND m.user_id=n.user_id AND m.status='active'
 AND p.data_scope=n.scope AND p.access_level IN ('view','edit')))))"""


def emit(cur, child, user, scope, key, title, body, data):
    cur.execute("""INSERT INTO notification.notifications
      (user_id,type_id,title,body,target_type,target_id,data,child_id,scope,event_key)
      SELECT %s,id,%s,%s,%s,%s,%s::jsonb,%s,%s,%s FROM notification.notification_types
      WHERE code=%s AND is_enabled ON CONFLICT(event_key) DO UPDATE SET resolved_at=NULL""",
      (str(user), title, body, scope, str(child), json.dumps(data), str(child), scope,
       key, f'{scope}_reminder'))


def _age_months(date_of_birth, now=None) -> int | None:
    """Tính tuổi theo tháng (floor) từ ngày sinh."""
    today = (now or datetime.now(timezone.utc)).date()
    if date_of_birth is None:
        return None
    dob = date_of_birth if hasattr(date_of_birth, 'year') else date_of_birth
    months = (today.year - dob.year) * 12 + (today.month - dob.month)
    if today.day < dob.day:
        months -= 1
    return max(0, months)


def generate(conn, user, now=None):
    now = now or datetime.now(timezone.utc)
    with conn.cursor() as cur:
        cur.execute('SELECT * FROM notification.preferences WHERE user_id=%s', (str(user),))
        prefs = cur.fetchone() or {}
        local = now + timedelta(minutes=prefs.get('timezone_offset', 420))
        can_emit = (local.hour, local.minute) >= (
            prefs.get('send_hour', 8),
            prefs.get('send_minute', 0),
        )
        day = local.date()
        cur.execute("""SELECT DISTINCT c.* FROM child.children c
          LEFT JOIN child.child_members m ON m.child_id=c.id AND m.user_id=%s AND m.status='active'
          WHERE c.deleted_at IS NULL AND (c.owner_user_id=%s OR m.id IS NOT NULL)""", (str(user), str(user)))
        children = cur.fetchall()
        for child in children:
            for scope in ('assessment', 'growth'):
                cur.execute("""SELECT 1 FROM child.children c WHERE c.id=%s AND
                  (c.owner_user_id=%s OR EXISTS(SELECT 1 FROM child.child_members m
                  JOIN child.child_member_permissions p ON p.member_id=m.id
                  WHERE m.child_id=c.id AND m.user_id=%s AND m.status='active'
                  AND p.data_scope=%s AND p.access_level='edit'))""",
                  (str(child['id']), str(user), str(user), scope))
                if not cur.fetchone():
                    continue
                if scope == 'assessment':
                    state = assessment.overview(conn, child, prefs.get('timezone_offset', 420))
                    age = state['age_months']
                    current_key = f'{user}:{child["id"]}:assessment:{age}:'
                    cur.execute("""UPDATE notification.notifications SET resolved_at=coalesce(resolved_at,now())
                      WHERE user_id=%s AND child_id=%s AND scope='assessment'
                      AND (event_key NOT LIKE %s OR %s)""",
                      (str(user), str(child['id']), current_key+'%', state['latest_completed'] is not None or not state['set']))
                    stage = assessment_stage(state, day)
                    if not can_emit or stage is None:
                        continue
                    if stage == 'repeat':
                        cur.execute("UPDATE notification.notifications SET resolved_at=coalesce(resolved_at,now()) WHERE event_key=%s", (current_key+'open',))
                    emit(cur, child['id'], user, scope, current_key+stage,
                         f'{child["full_name"]} · Đánh giá mốc {age} tháng',
                         f'Bài đánh giá mốc {age} tháng chưa hoàn thành. Bạn có thể bắt đầu hoặc tiếp tục bài đánh giá.',
                         {'age_months': age})
                else:
                    # --- Growth reminders: per-metric, gộp cùng hạn ---
                    age_months = _age_months(child['date_of_birth'], now)
                    # Ngoài phạm vi theo dõi (>= 61 tháng) → resolve tất cả
                    if age_months is not None and age_months >= 61:
                        cur.execute("""UPDATE notification.notifications SET resolved_at=coalesce(resolved_at,now())
                          WHERE user_id=%s AND child_id=%s AND scope='growth'""",
                          (str(user), str(child['id'])))
                        continue

                    metric_labels = [
                        ('weight', 'cân nặng'),
                        ('height', 'chiều cao'),
                        ('head_circumference', 'vòng đầu'),
                    ]
                    due_metrics = []  # (metric, label, due_on, stage_int)

                    for metric, label in metric_labels:
                        cur.execute('SELECT * FROM growth.reminder_settings WHERE child_id=%s AND user_id=%s AND metric=%s',
                                    (str(child['id']), str(user), metric))
                        setting = cur.fetchone() or {}

                        interval = effective_interval(metric, age_months or 0, setting)
                        if interval is None:
                            # Tắt hoặc ngoài phạm vi tuổi → resolve
                            cur.execute("""UPDATE notification.notifications SET resolved_at=coalesce(resolved_at,now())
                              WHERE user_id=%s AND child_id=%s AND scope='growth' AND data->>'metric'=%s""",
                              (str(user), str(child['id']), metric))
                            continue

                        cur.execute('SELECT max(measured_on) AS last FROM growth.measurements WHERE child_id=%s AND metric=%s AND deleted_at IS NULL',
                                    (str(child['id']), metric))
                        last = cur.fetchone()['last'] or child['date_of_birth']
                        due = growth_due(last, interval, setting)

                        # Invalidate stale notifications
                        cur.execute("""UPDATE notification.notifications SET resolved_at=coalesce(resolved_at,now())
                          WHERE user_id=%s AND child_id=%s AND scope='growth' AND data->>'metric'=%s
                          AND (data->>'last_measured_on' IS DISTINCT FROM %s OR data->>'due_on' IS DISTINCT FROM %s)""",
                          (str(user), str(child['id']), metric, last.isoformat(), due.isoformat()))

                        if not can_emit or day < due or day < child['date_of_birth']:
                            continue

                        # FRS §4: stage 0 = đúng hạn, stage 1 = nhắc lại sau 3 ngày
                        overdue_days = (day - due).days
                        stage = 1 if overdue_days >= 3 else 0
                        if stage == 1:
                            # Resolve stage 0 khi đã chuyển sang stage 1
                            cur.execute("UPDATE notification.notifications SET resolved_at=coalesce(resolved_at,now()) WHERE event_key=%s",
                                        (f'{user}:{child["id"]}:{metric}:{due}:0',))
                        due_metrics.append((metric, label, due, stage))

                    # --- Gộp các chỉ số cùng due_on + stage thành 1 notification ---
                    # Nhóm theo (due_on, stage)
                    groups: dict = {}
                    for metric, label, due, stage in due_metrics:
                        key = (due, stage)
                        groups.setdefault(key, []).append((metric, label))

                    for (due, stage), items in groups.items():
                        if len(items) == 1:
                            metric, label = items[0]
                            event_key = f'{user}:{child["id"]}:{metric}:{due}:{stage}'
                            title = f'{child["full_name"]} · Cập nhật {label}'
                            body = f'Đến lịch ghi số đo {label} của bé. Cập nhật khi bạn có số đo mới.'
                            data = {
                                'metric': metric,
                                'metrics': [metric],
                                'due_on': due.isoformat(),
                                'last_measured_on': None,
                            }
                        else:
                            # Nhiều chỉ số cùng hạn → gộp
                            metrics = [m for m, _ in items]
                            labels = [lb for _, lb in items]
                            # event_key: dùng tất cả metric sort để idempotent
                            key_metrics = '_'.join(sorted(metrics))
                            event_key = f'{user}:{child["id"]}:multi:{key_metrics}:{due}:{stage}'
                            joined = ', '.join(labels[:-1]) + ' và ' + labels[-1] if len(labels) > 1 else labels[0]
                            title = f'{child["full_name"]} · Cập nhật {joined}'
                            body = f'Đến lịch ghi số đo {joined} của bé. Cập nhật khi bạn có số đo mới.'
                            data = {
                                'metric': metrics[0],  # primary metric để deep link
                                'metrics': metrics,
                                'due_on': due.isoformat(),
                            }
                        emit(cur, child['id'], user, 'growth', event_key, title, body, data)


def inbox(conn, user, offset=0, limit=50):
    with conn.cursor() as cur:
        cur.execute(f"""SELECT count(*) AS count FROM notification.notifications n
          WHERE n.user_id=%s AND n.read_at IS NULL AND {ACCESS}""", (str(user),))
        count = cur.fetchone()['count']
        cur.execute(f"""SELECT n.*,t.code AS kind FROM notification.notifications n
          LEFT JOIN notification.notification_types t ON t.id=n.type_id
          WHERE n.user_id=%s AND {ACCESS} ORDER BY n.created_at DESC,n.id DESC LIMIT %s OFFSET %s""",
          (str(user), limit+1, offset))
        rows = cur.fetchall()
        return {'items': rows[:limit], 'has_more': len(rows) > limit, 'unread_count': count}
