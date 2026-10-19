"""Chạy với PostgreSQL local đã migrate (scripts/migrate.ps1); không có DB thì bỏ qua."""

import datetime as dt

import psycopg2
import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app
from app.seed import demo

MOTHER, FATHER = demo.PARENTS[0][0], demo.PARENTS[1][0]
CHILD = demo.CHILDREN[0][0]  # Bảo An, 8 tháng, của mẹ
ADMIN = {"X-Admin-Role": "content_manager"}


@pytest.fixture(scope="module")
def db():
    try:
        conn = psycopg2.connect(settings.database_url, connect_timeout=2)
    except psycopg2.OperationalError:
        pytest.skip("PostgreSQL không chạy")
    demo.seed()
    yield conn
    conn.close()


@pytest.fixture
def client(db, monkeypatch):
    monkeypatch.setattr(settings, "dev_auth", True)
    with db, db.cursor() as cur:
        cur.execute("DELETE FROM health.child_vaccinations WHERE child_id = %s", (CHILD,))
    yield TestClient(app)
    with db, db.cursor() as cur:
        cur.execute("DELETE FROM health.child_vaccinations WHERE child_id = %s", (CHILD,))
        cur.execute("DELETE FROM health.vaccine_schedules WHERE code LIKE 'test-%' AND after_schedule_id IS NOT NULL")
        cur.execute("DELETE FROM health.vaccine_schedules WHERE code LIKE 'test-%'")
        cur.execute("DELETE FROM health.vaccine_products WHERE code LIKE 'test-%'")
        cur.execute("DELETE FROM health.vaccines WHERE code LIKE 'test-%'")


def as_user(user: str) -> dict:
    return {"X-User-Id": user}


def test_schedule_contains_tcmr_and_service_vaccines(client):
    schedule = client.get("/vaccines/schedule").json()
    doses = {d["id"]: d for d in schedule["doses"]}
    vaccines = {v["code"]: v for v in schedule["vaccines"]}
    assert [d["id"] for d in schedule["doses"][:3]] == ["bcg", "hepb-0", "rsv-1"]
    assert (doses["je-2"]["ageMonths"], doses["je-2"]["offsetDays"]) == (12, 14)
    assert doses["6in1-1"]["ageWeeks"] == 6 and not doses["6in1-1"]["isTcmr"]
    assert doses["pcv-2"]["afterDose"] == "pcv-1" and doses["pcv-2"]["minIntervalDays"] == 28
    assert doses["flu-yearly"]["repeatEveryMonths"] == 12
    assert doses["je-4"]["isTcmr"] is False and doses["je-1"]["isTcmr"] is True
    assert vaccines["rota"]["isTcmr"] is False
    assert {p["code"]: p["doseCount"] for p in vaccines["rota"]["products"]}["rotateq"] == 3
    # 5 trong 1 (TCMR) và 6 trong 1 (dịch vụ) là 2 phương án của cùng nhóm
    assert vaccines["5in1"]["choiceGroup"] == vaccines["6in1"]["choiceGroup"] == "dtp"
    assert vaccines["5in1"]["choiceDefault"] and not vaccines["6in1"]["choiceDefault"]


def test_save_list_and_delete_records(client):
    yesterday = (dt.date.today() - dt.timedelta(days=1)).isoformat()
    later = (dt.date.today() + dt.timedelta(days=20)).isoformat()
    records = [
        {"id": "bcg", "given": True, "date": yesterday, "place": "Trạm y tế"},
        {"id": "custom-1-0", "groupId": "custom-1", "custom": True, "name": "Cúm",
         "prevents": "Cúm mùa", "doseLabel": "Mũi 1", "given": False, "date": later,
         "place": "VNVC"},
    ]
    url = f"/children/{CHILD}/vaccinations"
    assert client.put(url, json={"records": records}, headers=as_user(MOTHER)).status_code == 200
    # Lưu lại cùng mũi = cập nhật, không tạo dòng mới
    records[1] |= {"given": True, "date": yesterday, "reaction": "Sốt nhẹ"}
    assert client.put(url, json={"records": records[1:]}, headers=as_user(MOTHER)).status_code == 200

    saved = {r["id"]: r for r in client.get(url, headers=as_user(MOTHER)).json()}
    assert saved.keys() == {"bcg", "custom-1-0"}
    assert saved["bcg"]["name"] == "BCG" and saved["bcg"]["place"] == "Trạm y tế"
    expected = {"given": True, "reaction": "Sốt nhẹ", "place": "VNVC", "groupId": "custom-1"}
    assert {key: saved["custom-1-0"][key] for key in expected} == expected

    assert client.delete(f"{url}/bcg", headers=as_user(MOTHER)).status_code == 204
    assert [r["id"] for r in client.get(url, headers=as_user(MOTHER)).json()] == ["custom-1-0"]


def test_repeat_occurrence_and_product(client):
    url = f"/children/{CHILD}/vaccinations"
    yesterday = (dt.date.today() - dt.timedelta(days=1)).isoformat()
    records = [
        {"id": "rota-1", "product": "rotarix", "given": True, "date": yesterday},
        {"id": "typhoid-1@1", "given": False,
         "date": (dt.date.today() + dt.timedelta(days=900)).isoformat()},
    ]
    response = client.put(url, json={"records": records}, headers=as_user(MOTHER))
    assert response.status_code == 200, response.text
    saved = {r["id"]: r for r in client.get(url, headers=as_user(MOTHER)).json()}
    assert saved["rota-1"]["product"] == "rotarix"
    assert saved["typhoid-1@1"]["given"] is False
    assert client.delete(f"{url}/typhoid-1@1", headers=as_user(MOTHER)).status_code == 204
    assert "typhoid-1@1" not in [r["id"] for r in client.get(url, headers=as_user(MOTHER)).json()]

    for bad in (
        {"id": "bcg", "product": "rotarix", "given": True, "date": yesterday},  # sai vắc xin
        {"id": "bcg@1", "given": True, "date": yesterday},  # mũi không lặp lại
    ):
        assert client.put(url, json={"records": [bad]}, headers=as_user(MOTHER)).status_code == 422


def test_vaccine_plans(client, db):
    url = f"/children/{CHILD}/vaccine-plans"
    with db, db.cursor() as cur:
        cur.execute("DELETE FROM health.child_vaccine_plans WHERE child_id = %s", (CHILD,))
    body = {"plans": {"6in1": True, "5in1": False, "dengue": False}}
    assert client.put(url, json=body, headers=as_user(MOTHER)).json() == body["plans"]
    assert client.put(url, json={"plans": {"dengue": None}}, headers=as_user(MOTHER)).json() == {
        "6in1": True, "5in1": False}
    assert client.put(url, json={"plans": {"khong-co": True}}, headers=as_user(MOTHER)).status_code == 422
    assert client.get(url, headers=as_user(FATHER)).status_code == 404
    with db, db.cursor() as cur:
        cur.execute("DELETE FROM health.child_vaccine_plans WHERE child_id = %s", (CHILD,))


def test_scheduled_date_kept_when_marked_given(client):
    url = f"/children/{CHILD}/vaccinations"
    today = dt.date.today()
    appointment = (today + dt.timedelta(days=5)).isoformat()
    given_day = (today - dt.timedelta(days=1)).isoformat()
    due_day = (today - dt.timedelta(days=8)).isoformat()

    def put(record):
        response = client.put(url, json={"records": [record]}, headers=as_user(MOTHER))
        assert response.status_code == 200, response.text
        return response.json()[0]

    # Bố mẹ đặt lịch hẹn rồi ghi nhận (không gửi scheduledDate) -> giữ ngày + nơi hẹn
    put({"id": "pcv-1", "given": False, "date": appointment, "place": "VNVC Hà Đông"})
    saved = put({"id": "pcv-1", "given": True, "date": given_day, "place": "VNVC Cầu Giấy"})
    assert (saved["date"], saved["scheduledDate"]) == (given_day, appointment)
    assert (saved["place"], saved["appointmentPlace"]) == ("VNVC Cầu Giấy", "VNVC Hà Đông")

    # Chưa từng hẹn: mobile gửi ngày dự kiến làm ngày hẹn
    saved = put({"id": "bcg", "given": True, "date": given_day, "scheduledDate": due_day})
    assert saved["scheduledDate"] == due_day

    # Mũi tự thêm đã tiêm ngay, không có ngày hẹn
    saved = put({"id": "custom-z-0", "custom": True, "name": "Dại", "given": True, "date": given_day})
    assert saved["scheduledDate"] is None


def test_rejects_invalid_records(client):
    url = f"/children/{CHILD}/vaccinations"
    future = (dt.date.today() + dt.timedelta(days=3)).isoformat()
    for record in (
        {"id": "khong-co", "given": True, "date": dt.date.today().isoformat()},
        {"id": "bcg", "given": True, "date": future},
        {"id": "bcg", "given": True, "date": "2000-01-01"},
    ):
        response = client.put(url, json={"records": [record]}, headers=as_user(MOTHER))
        assert response.status_code == 422, record


def test_child_access(client):
    url = f"/children/{CHILD}/vaccinations"
    assert client.get(url).status_code == 401
    assert client.get(url, headers=as_user(FATHER)).status_code == 404


def test_admin_requires_permission(client):
    assert client.get("/admin/vaccines", headers={"X-Admin-Role": "moderator"}).status_code == 403
    assert client.get("/admin/vaccines", headers=ADMIN).status_code == 200


def test_admin_schedule_crud(client):
    vaccine = client.post("/admin/vaccines", headers=ADMIN,
                          json={"code": "test-flu", "name": "Cúm (test)"}).json()
    body = {"vaccineId": vaccine["id"], "code": "test-flu-1", "doseNumber": 1, "ageWeeks": 6}
    created = client.post("/admin/vaccine-schedules", headers=ADMIN, json=body)
    assert created.status_code == 201
    assert (created.json()["ageMonths"], created.json()["offsetDays"]) == (1, 12)
    second = client.post("/admin/vaccine-schedules", headers=ADMIN, json={
        "vaccineId": vaccine["id"], "code": "test-flu-2", "doseNumber": 2, "ageMonths": 7,
        "afterScheduleId": created.json()["id"], "minIntervalDays": 28}).json()
    assert second["afterCode"] == "test-flu-1"
    bcg = next(s for s in client.get("/admin/vaccine-schedules", headers=ADMIN).json() if s["code"] == "bcg")
    assert client.patch(f"/admin/vaccine-schedules/{second['id']}", headers=ADMIN,
                        json={"afterScheduleId": bcg["id"]}).status_code == 422
    assert client.delete(f"/admin/vaccine-schedules/{created.json()['id']}", headers=ADMIN).status_code == 409
    assert client.delete(f"/admin/vaccine-schedules/{second['id']}", headers=ADMIN).status_code == 204
    assert client.post("/admin/vaccine-schedules", headers=ADMIN, json=body).status_code == 409

    schedule_id = created.json()["id"]
    hidden = client.patch(f"/admin/vaccine-schedules/{schedule_id}", headers=ADMIN,
                          json={"isActive": False}).json()
    assert hidden["isActive"] is False
    assert "test-flu-1" not in [d["id"] for d in client.get("/vaccines/schedule").json()["doses"]]
    assert client.delete(f"/admin/vaccine-schedules/{schedule_id}", headers=ADMIN).status_code == 204


def test_admin_products(client):
    rota = next(v for v in client.get("/admin/vaccines", headers=ADMIN).json() if v["code"] == "rota")
    created = client.post("/admin/vaccine-products", headers=ADMIN, json={
        "vaccineId": rota["id"], "code": "test-rota", "name": "Rota thử", "doseCount": 2})
    assert created.status_code == 201
    updated = client.patch(f"/admin/vaccine-products/{created.json()['id']}", headers=ADMIN,
                           json={"isActive": False}).json()
    assert updated["isActive"] is False
    assert "test-rota" not in [p["code"] for p in next(
        v for v in client.get("/vaccines/schedule").json()["vaccines"] if v["code"] == "rota")["products"]]


def test_admin_custom_dose_report(client, db):
    second_child = demo.CHILDREN[1][0]  # Gia Linh, cũng của mẹ
    day = (dt.date.today() - dt.timedelta(days=2)).isoformat()

    def custom(ref, name, prevents=None, given=True):
        return {"id": ref, "custom": True, "name": name, "prevents": prevents,
                "given": given, "date": day}

    for child, records in (
        (CHILD, [custom("custom-a-0", "Dại", "Bệnh dại"), custom("custom-a-1", "dại "),
                 custom("custom-b-0", "HPV", given=False), custom("custom-c-0", "Cúm mùa")]),
        (second_child, [custom("custom-d-0", "  DẠI", "Bệnh dại"), custom("custom-e-0", "cúm  mùa")]),
    ):
        response = client.put(f"/children/{child}/vaccinations", json={"records": records},
                              headers=as_user(MOTHER))
        assert response.status_code == 200, response.text
    try:
        report = client.get("/admin/vaccinations/custom-summary", headers=ADMIN).json()
        items = {item["key"]: item for item in report["items"]}
        assert items["dại"]["childCount"] == 2 and items["dại"]["doseCount"] == 3
        assert items["dại"]["prevents"] == "Bệnh dại"
        assert items["cúm mùa"]["catalogVaccine"] == "flu"
        # 1 bé, chưa tiêm — vẫn hiện
        assert items["hpv"]["childCount"] == 1 and items["hpv"]["plannedCount"] == 1
        assert report["totalChildren"] == 2 and report["totalDoses"] == 6
        assert all("childId" not in item for item in report["items"])
        assert client.get("/admin/vaccinations/custom-summary",
                          headers={"X-Admin-Role": "moderator"}).status_code == 403
    finally:
        with db, db.cursor() as cur:
            cur.execute("DELETE FROM health.child_vaccinations WHERE child_id = %s", (second_child,))


def test_dev_profiles_register_device_child(client, db):
    parent_id, child_id = "00000000-0000-4000-8000-0000000000aa", "00000000-0000-4000-8000-0000000000ab"
    profile = {
        "parent": {"id": parent_id, "email": "moi.dang.ky@example.test", "fullName": "Phụ huynh mới"},
        "child": {"id": child_id, "fullName": "Bé mới", "dateOfBirth": "2026-01-05", "gender": "female"},
    }
    try:
        assert client.put("/dev/profiles", json=profile).status_code == 204
        assert client.put("/dev/profiles", json=profile).status_code == 204  # chạy lại an toàn
        record = {"id": "custom-x-0", "custom": True, "name": "Viêm não mô cầu B", "given": False,
                  "date": (dt.date.today() + dt.timedelta(days=10)).isoformat()}
        response = client.put(f"/children/{child_id}/vaccinations", json={"records": [record]},
                              headers=as_user(parent_id))
        assert response.status_code == 200, response.text
        names = [i["name"] for i in client.get("/admin/vaccinations/custom-summary", headers=ADMIN).json()["items"]]
        assert names[0] == "Viêm não mô cầu B"  # mới nhất lên đầu
        # Bé đã thuộc người khác / email trùng tài khoản khác
        stolen = {**profile, "parent": {**profile["parent"], "id": FATHER, "email": "bo@trackchildren.vn"}}
        assert client.put("/dev/profiles", json=stolen).status_code == 403
        clash = {**profile, "parent": {**profile["parent"], "id": "00000000-0000-4000-8000-0000000000ac"},
                 "child": {**profile["child"], "id": "00000000-0000-4000-8000-0000000000ad"}}
        assert client.put("/dev/profiles", json=clash).status_code == 409
    finally:
        with db, db.cursor() as cur:
            cur.execute("DELETE FROM child.child_data_change_logs WHERE child_id = %s", (child_id,))
            cur.execute("DELETE FROM child.children WHERE id = %s", (child_id,))
            cur.execute("DELETE FROM account.users WHERE id = %s", (parent_id,))


def test_dev_profiles_disabled_without_dev_auth(client, monkeypatch):
    monkeypatch.setattr(settings, "dev_auth", False)
    assert client.put("/dev/profiles", json={}).status_code == 404
