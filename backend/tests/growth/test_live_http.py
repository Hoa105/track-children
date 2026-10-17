"""Real HTTP transport, PostgreSQL and session lifecycle (no dependency overrides)."""
import socket
import threading
import time
import httpx
import psycopg
import uvicorn
from argon2 import PasswordHasher
from app.main import app


def test_live_http_lifecycle(env):
    with psycopg.connect(env['url']) as db:
        db.execute('UPDATE account.users SET password_hash=%s WHERE id=%s',
            (PasswordHasher().hash('live-test-password'),env['users']['owner']))
    sock=socket.socket()
    sock.bind(('127.0.0.1',0))
    port=sock.getsockname()[1]
    server=uvicorn.Server(uvicorn.Config(app,log_level='error'))
    thread=threading.Thread(target=server.run,kwargs={'sockets':[sock]},daemon=True)
    thread.start()
    try:
        for _ in range(100):
            if server.started: break
            time.sleep(.02)
        assert server.started
        with httpx.Client(base_url=f'http://127.0.0.1:{port}/api/v1',timeout=15) as client:
            session=client.post('/auth/login',json={'email':'owner@example.test','password':'live-test-password'})
            assert session.status_code==200
            tokens=session.json()
            client.headers['Authorization']='Bearer '+tokens['accessToken']
            child=client.post('/children',json={'fullName':'Live child','dateOfBirth':'2026-02-17','gender':'female'})
            assert child.status_code==201
            cid=child.json()['id']
            path=f'/children/{cid}/growth'
            result=client.put(path+'/days/2026-10-15',json={
                'weightKg':8.4,'height':{'value':69.5,'measurePosition':'lying'}})
            assert result.status_code==200 and result.json()['bmi']['value']==17.39
            assert client.get(path).json()['summary']['bmi']['value']==17.39
            mid=result.json()['measurements'][0]['id']
            assert client.delete(path+'/measurements/'+mid).status_code==204
            assert client.get(path).json()['summary']['bmi'] is None
            assert client.post('/auth/logout',json={'refreshToken':tokens['refreshToken']}).status_code==204
            assert client.get(path).status_code==401
    finally:
        server.should_exit=True
        thread.join(timeout=10)
        sock.close()
