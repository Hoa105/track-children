"""Run every minute: python -m scripts.deliver_notifications.

FCM uses Application Default Credentials. Missing credentials leave the outbox queued.
"""
import json
from datetime import datetime, timedelta, timezone
from app.core.database import get_db
from app.features.notifications import service


def run():
    connections = get_db()
    conn = next(connections)
    try:
        with conn, conn.cursor() as cur:
            # One generator/dispatcher at a time, including overlapping cron runs.
            cur.execute("SELECT pg_try_advisory_xact_lock(927027) AS locked")
            if not cur.fetchone()['locked']:
                return
            cur.execute("SELECT id FROM account.users WHERE status='active'")
            for user in cur.fetchall():
                service.generate(conn,user['id'])
            cur.execute(f"""INSERT INTO notification.push_outbox(notification_id,device_token_id)
              SELECT n.id,d.id FROM notification.notifications n
              JOIN account.device_tokens d ON d.user_id=n.user_id AND d.is_active
              JOIN account.user_sessions s ON s.id=d.session_id AND s.revoked_at IS NULL AND s.expires_at>now()
              LEFT JOIN notification.preferences p ON p.user_id=n.user_id
              WHERE n.event_key IS NOT NULL AND n.resolved_at IS NULL AND n.read_at IS NULL
              AND n.created_at>now()-interval '24 hours' AND coalesce(p.push_enabled,true)
              AND {service.ACCESS} ON CONFLICT DO NOTHING""")
        try:
            import os
            import firebase_admin
            from firebase_admin import messaging
            if 'GOOGLE_APPLICATION_CREDENTIALS' not in os.environ:
                backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                env_path = os.path.join(backend_dir, '.env')
                if os.path.exists(env_path):
                    with open(env_path, 'r', encoding='utf-8') as f:
                        for line in f:
                            clean = line.strip()
                            if clean.startswith('GOOGLE_APPLICATION_CREDENTIALS='):
                                val = clean.split('=', 1)[1].strip().strip('"').strip("'")
                                if val:
                                    if not os.path.isabs(val):
                                        val = os.path.normpath(os.path.join(backend_dir, val))
                                    os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = val
                                break
                if 'GOOGLE_APPLICATION_CREDENTIALS' not in os.environ:
                    default_key = os.path.join(backend_dir, 'firebase-service-account.json')
                    if os.path.exists(default_key):
                        os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = default_key

            if not firebase_admin._apps:
                firebase_admin.initialize_app()
            # Validate credentials before taking any attempts.
            firebase_admin.get_app().credential.get_access_token()
        except Exception as exc:
            print(f'Push unavailable; inbox remains active: {type(exc).__name__}')
            return
        with conn, conn.cursor() as cur:
            cur.execute("SELECT pg_try_advisory_xact_lock(927028) AS locked")
            if not cur.fetchone()['locked']:
                return
            cur.execute(f"""SELECT o.*,n.title,n.body,n.target_type,n.target_id,n.data,
              d.fcm_token,d.user_id AS device_user,n.user_id,
              (d.is_active AND n.resolved_at IS NULL AND n.read_at IS NULL
               AND coalesce(p.push_enabled,true) AND s.revoked_at IS NULL AND s.expires_at>now()
               AND {service.ACCESS}) AS allowed
              FROM notification.push_outbox o JOIN notification.notifications n ON n.id=o.notification_id
              JOIN account.device_tokens d ON d.id=o.device_token_id
              LEFT JOIN account.user_sessions s ON s.id=d.session_id
              LEFT JOIN notification.preferences p ON p.user_id=n.user_id
              WHERE o.status='queued' AND o.next_attempt_at<=now()
              ORDER BY o.next_attempt_at LIMIT 100 FOR UPDATE OF o SKIP LOCKED""")
            for row in cur.fetchall():
                status,error='cancelled',None
                if row['allowed'] and row['device_user']==row['user_id']:
                    try:
                        messaging.send(messaging.Message(token=row['fcm_token'],
                            notification=messaging.Notification(title=row['title'],body=row['body']),
                            data={'notification_id':str(row['notification_id']),'kind':row['target_type'],
                                  'child_id':row['target_id'],'payload':json.dumps(row['data'] or {})},
                            android=messaging.AndroidConfig(notification=messaging.AndroidNotification(
                                channel_id='care_reminders',tag=str(row['notification_id'])))))
                        status='sent'
                    except messaging.UnregisteredError:
                        cur.execute('UPDATE account.device_tokens SET is_active=false WHERE id=%s',(str(row['device_token_id']),))
                        status,error='failed','unregistered'
                    except Exception as exc:
                        status='failed' if row['attempts']>=4 else 'queued'
                        error=type(exc).__name__
                cur.execute("""UPDATE notification.push_outbox SET status=%s,attempts=attempts+1,
                  last_error=%s,next_attempt_at=%s WHERE notification_id=%s AND device_token_id=%s""",
                  (status,error,datetime.now(timezone.utc)+timedelta(minutes=2**row['attempts']),
                   str(row['notification_id']),str(row['device_token_id'])))
    finally:
        connections.close()

if __name__ == '__main__':
    run()
