"""Restartable auth worker. Run separately from the API process."""
import logging
import signal
import json
import sys
from datetime import datetime,timezone
from pathlib import Path
from uuid import uuid4
from socket import gethostname
from threading import Event
from app.core.config import settings
from app.features.auth.maintenance import main

def heartbeat_path():
    return (Path(settings.auth_rate_limit_path).parent if settings.auth_rate_limit_path else Path('.runtime'))/('auth-worker-'+gethostname()+'.json')

def healthy():
    if not settings.auth_v2_enabled:return True
    try:
        stamp=json.loads(heartbeat_path().read_text(encoding='utf-8'))['lastSuccess']
        return 0<=(datetime.now(timezone.utc)-datetime.fromisoformat(stamp)).total_seconds()<=max(300,settings.auth_worker_interval_seconds*4)
    except (OSError,ValueError,KeyError,TypeError):return False

def run():
    stopped=Event()
    for sig in (signal.SIGINT,signal.SIGTERM):
        signal.signal(sig,lambda *_:stopped.set())
    while not stopped.is_set():
        try:
            if settings.auth_v2_enabled:
                main()
                path=heartbeat_path();path.parent.mkdir(parents=True,exist_ok=True)
                temporary=path.with_name(path.name+'.'+uuid4().hex+'.tmp')
                temporary.write_text(json.dumps({'lastSuccess':datetime.now(timezone.utc).isoformat()}),encoding='utf-8')
                temporary.replace(path)
        except Exception:
            # Do not log exception messages: provider/DB exceptions can contain identifiers.
            logging.error('Auth maintenance failed; retry scheduled')
        stopped.wait(settings.auth_worker_interval_seconds)

if __name__=='__main__':
    if '--health' in sys.argv:sys.exit(0 if healthy() else 1)
    run()
