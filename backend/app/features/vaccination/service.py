"""Vaccination business logic (F05.2 sổ tiêm của bé, F16.1 danh mục & lịch tiêm).

Ngày dự kiến của từng mũi do mobile tính (theo ngày sinh, mũi trước đã tiêm,
lần lặp); backend lưu lịch tham chiếu và sổ tiêm.
"""

import datetime as dt
import json
from uuid import UUID

from fastapi import HTTPException, status
from psycopg2 import errors
from psycopg2.extensions import connection as Connection

from app.features.vaccination.schema import (
    AdminProductCreate,
    AdminProductUpdate,
    AdminScheduleCreate,
    AdminScheduleUpdate,
    AdminVaccineCreate,
    AdminVaccineUpdate,
    VaccinationRecord,
)

SCOPE = "vaccination"
OCCURRENCE_SEPARATOR = "@"  # mũi lặp lại: "flu-yearly@2" = lần nhắc thứ 2


def split_dose_ref(ref: str) -> tuple[str, int]:
    """'flu-yearly@2' -> ('flu-yearly', 2); 'bcg' -> ('bcg', 0)."""
    code, _, occurrence = ref.partition(OCCURRENCE_SEPARATOR)
    if not occurrence:
        return code, 0
    if not occurrence.isdigit() or not 1 <= int(occurrence) <= 100:
        raise HTTPException(422, f"Lần lặp không hợp lệ: {ref}")
    return code, int(occurrence)


# ---------------------------------------------------------------------
# Lịch tiêm (mobile đọc)
# ---------------------------------------------------------------------
def get_schedule(conn: Connection) -> dict:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT v.code, v.name, coalesce(v.disease, '') AS prevents, v.is_mandatory AS is_tcmr,
                   v.description, v.choice_group, v.choice_option, v.choice_label, v.choice_default,
                   coalesce(json_agg(json_build_object(
                       'code', p.code, 'name', p.name, 'origin', p.origin, 'doseCount', p.dose_count)
                       ORDER BY p.id) FILTER (WHERE p.id IS NOT NULL), '[]') AS products
            FROM health.vaccines v
            LEFT JOIN health.vaccine_products p ON p.vaccine_id = v.id AND p.is_active
            WHERE v.is_active
            GROUP BY v.id
            ORDER BY v.sort_order, v.id
            """
        )
        vaccines = cur.fetchall()
        cur.execute(
            """
            SELECT s.code AS id, v.code AS vaccine, s.dose_number,
                   coalesce(s.dose_label, 'Mũi ' || s.dose_number) AS dose_label,
                   s.age_weeks, s.age_months, s.offset_days, prev.code AS after_dose,
                   s.min_interval_days, s.repeat_every_months, s.repeat_until_months,
                   coalesce(s.is_mandatory, v.is_mandatory) AS is_tcmr, s.note
            FROM health.vaccine_schedules s
            JOIN health.vaccines v ON v.id = s.vaccine_id
            LEFT JOIN health.vaccine_schedules prev ON prev.id = s.after_schedule_id
            WHERE s.is_active AND v.is_active AND s.code IS NOT NULL
            ORDER BY s.age_from_days, v.sort_order, s.dose_number
            """
        )
        doses = cur.fetchall()
    return {"vaccines": vaccines, "doses": doses}


# ---------------------------------------------------------------------
# Sổ tiêm của bé (health.child_vaccinations)
# ---------------------------------------------------------------------
_RECORD_SELECT = """
    SELECT cv.id AS row_id,
           coalesce(s.code || CASE WHEN cv.occurrence > 0 THEN '@' || cv.occurrence ELSE '' END,
                    cv.client_ref) AS id,
           cv.schedule_id IS NULL AS custom,
           cv.group_ref AS group_id,
           coalesce(v.name, cv.custom_name) AS name,
           coalesce(v.disease, cv.custom_disease, '') AS prevents,
           coalesce(s.dose_label, cv.dose_label, 'Mũi tiêm') AS dose_label,
           pr.code AS product,
           cv.status = 'done' AS given,
           coalesce(cv.vaccinated_at, cv.scheduled_date) AS date,
           cv.scheduled_date,
           coalesce(CASE WHEN cv.status = 'done' THEN cv.place ELSE cv.appointment_place END, '') AS place,
           cv.appointment_place,
           coalesce(cv.reaction_note, '') AS reaction,
           coalesce(cv.note, '') AS note
    FROM health.child_vaccinations cv
    LEFT JOIN health.vaccine_schedules s ON s.id = cv.schedule_id
    LEFT JOIN health.vaccines v ON v.id = s.vaccine_id
    LEFT JOIN health.vaccine_products pr ON pr.id = cv.product_id
"""


def list_child_vaccinations(conn: Connection, child_id: UUID) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(
            _RECORD_SELECT
            + " WHERE cv.child_id = %s AND (cv.status <> 'skipped')"
            + " ORDER BY coalesce(cv.vaccinated_at, cv.scheduled_date), cv.created_at",
            (str(child_id),),
        )
        rows = cur.fetchall()
    # Mũi theo lịch chưa tiêm và không có ngày hẹn: mobile không biểu diễn được
    return [row for row in rows if row["date"] is not None]


def _validate_dates(records: list[VaccinationRecord], dob: dt.date, today: dt.date) -> None:
    ids: set[str] = set()
    for record in records:
        if record.id in ids:
            raise HTTPException(422, "Mũi tiêm bị trùng")
        ids.add(record.id)
        if record.date < dob or (record.given and record.date > today):
            raise HTTPException(422, f"Ngày tiêm không hợp lệ: {record.id}")
        if record.scheduled_date is not None and record.scheduled_date < dob:
            raise HTTPException(422, f"Ngày hẹn không hợp lệ: {record.id}")


def save_child_vaccinations(
    conn: Connection,
    child: dict,
    user_id: UUID,
    records: list[VaccinationRecord],
    today: dt.date | None = None,
) -> list[dict]:
    """Thêm / cập nhật nhiều mũi trong 1 transaction (giống DemoStore.saveVaccinations)."""
    _validate_dates(records, child["date_of_birth"], today or dt.date.today())
    child_id = str(child["id"])
    with conn, conn.cursor() as cur:
        refs = {r.id: split_dose_ref(r.id) for r in records if not r.custom}
        schedules: dict[str, dict] = {}
        if refs:
            cur.execute(
                """
                SELECT code, id, vaccine_id, repeat_every_months FROM health.vaccine_schedules
                WHERE code = ANY(%s)
                """,
                (list({code for code, _ in refs.values()}),),
            )
            schedules = {row["code"]: row for row in cur.fetchall()}
        unknown = sorted(
            ref for ref, (code, occurrence) in refs.items()
            if code not in schedules
            or (occurrence > 0 and schedules[code]["repeat_every_months"] is None)
        )
        if unknown:
            raise HTTPException(422, f"Mũi không có trong lịch tiêm: {', '.join(unknown)}")

        products: dict[str, dict] = {}
        product_codes = [r.product for r in records if r.product]
        if product_codes:
            cur.execute(
                "SELECT code, id, vaccine_id FROM health.vaccine_products WHERE code = ANY(%s)",
                (product_codes,),
            )
            products = {row["code"]: row for row in cur.fetchall()}

        saved_ids: list[str] = []
        for record in records:
            given = record.given
            product_id = None
            if record.product:
                product = products.get(record.product)
                expected_vaccine = None if record.custom else schedules[refs[record.id][0]]["vaccine_id"]
                if product is None or (expected_vaccine and product["vaccine_id"] != expected_vaccine):
                    raise HTTPException(422, f"Sản phẩm không thuộc vắc xin của mũi {record.id}")
                product_id = product["id"]
            values = {
                "child": child_id,
                "user": str(user_id),
                "product": product_id,
                "status": "done" if given else "planned",
                "vaccinated_at": record.date if given else None,
                # Đã tiêm: ngày hẹn / ngày dự kiến lúc ghi nhận (NULL = giữ giá trị đã lưu)
                "scheduled_date": record.scheduled_date if given else record.date,
                "place": record.place.strip() or None if given else None,
                "appointment_place": (
                    (record.appointment_place or "").strip() or None if given
                    else record.place.strip() or None
                ),
                "keep_appointment": given,
                "reaction": record.reaction.strip() or None if given else None,
                "note": record.note.strip() or None,
            }
            if record.custom:
                cur.execute(
                    """
                    INSERT INTO health.child_vaccinations
                      (child_id, client_ref, group_ref, custom_name, custom_disease, dose_label,
                       product_id, status, vaccinated_at, scheduled_date, place, appointment_place,
                       reaction_note, note, created_by, updated_by)
                    VALUES (%(child)s, %(ref)s, %(group)s, %(name)s, %(prevents)s, %(dose)s,
                       %(product)s, %(status)s, %(vaccinated_at)s, %(scheduled_date)s, %(place)s,
                       %(appointment_place)s, %(reaction)s, %(note)s, %(user)s, %(user)s)
                    ON CONFLICT (child_id, client_ref) WHERE client_ref IS NOT NULL DO UPDATE SET
                      group_ref = EXCLUDED.group_ref, custom_name = EXCLUDED.custom_name,
                      custom_disease = EXCLUDED.custom_disease, dose_label = EXCLUDED.dose_label,
                      product_id = EXCLUDED.product_id,
                      status = EXCLUDED.status, vaccinated_at = EXCLUDED.vaccinated_at,
                      scheduled_date = CASE WHEN %(keep_appointment)s
                          THEN coalesce(EXCLUDED.scheduled_date, child_vaccinations.scheduled_date)
                          ELSE EXCLUDED.scheduled_date END,
                      place = EXCLUDED.place,
                      appointment_place = CASE WHEN %(keep_appointment)s
                          THEN coalesce(EXCLUDED.appointment_place, child_vaccinations.appointment_place)
                          ELSE EXCLUDED.appointment_place END,
                      reaction_note = EXCLUDED.reaction_note, note = EXCLUDED.note,
                      updated_by = EXCLUDED.updated_by
                    RETURNING id, (xmax = 0) AS inserted
                    """,
                    {
                        **values,
                        "ref": record.id,
                        "group": record.group_id,
                        "name": (record.name or "").strip(),
                        "prevents": (record.prevents or "").strip() or None,
                        "dose": (record.dose_label or "").strip() or None,
                    },
                )
            else:
                code, occurrence = refs[record.id]
                cur.execute(
                    """
                    INSERT INTO health.child_vaccinations
                      (child_id, schedule_id, occurrence, product_id, status, vaccinated_at,
                       scheduled_date, place, appointment_place, reaction_note, note,
                       created_by, updated_by)
                    VALUES (%(child)s, %(schedule)s, %(occurrence)s, %(product)s, %(status)s,
                       %(vaccinated_at)s, %(scheduled_date)s, %(place)s, %(appointment_place)s,
                       %(reaction)s, %(note)s, %(user)s, %(user)s)
                    ON CONFLICT (child_id, schedule_id, occurrence) DO UPDATE SET
                      product_id = EXCLUDED.product_id,
                      status = EXCLUDED.status, vaccinated_at = EXCLUDED.vaccinated_at,
                      scheduled_date = CASE WHEN %(keep_appointment)s
                          THEN coalesce(EXCLUDED.scheduled_date, child_vaccinations.scheduled_date)
                          ELSE EXCLUDED.scheduled_date END,
                      place = EXCLUDED.place,
                      appointment_place = CASE WHEN %(keep_appointment)s
                          THEN coalesce(EXCLUDED.appointment_place, child_vaccinations.appointment_place)
                          ELSE EXCLUDED.appointment_place END,
                      reaction_note = EXCLUDED.reaction_note, note = EXCLUDED.note,
                      updated_by = EXCLUDED.updated_by
                    RETURNING id, (xmax = 0) AS inserted
                    """,
                    {**values, "schedule": schedules[code]["id"], "occurrence": occurrence},
                )
            row = cur.fetchone()
            saved_ids.append(str(row["id"]))
            _log_change(
                cur, child_id, user_id, row["id"], "create" if row["inserted"] else "update",
                record.model_dump(mode="json", by_alias=True),
            )

        cur.execute(_RECORD_SELECT + " WHERE cv.id = ANY(%s::uuid[])", (saved_ids,))
        return cur.fetchall()


def delete_child_vaccination(conn: Connection, child_id: UUID, user_id: UUID, ref: str) -> None:
    """Bỏ đánh dấu đã tiêm (mũi theo lịch) hoặc xóa mũi tự thêm. Không có thì bỏ qua."""
    code, occurrence = split_dose_ref(ref)
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            DELETE FROM health.child_vaccinations
            WHERE child_id = %(child)s
              AND (client_ref = %(ref)s
                   OR (occurrence = %(occurrence)s AND schedule_id =
                       (SELECT id FROM health.vaccine_schedules WHERE code = %(code)s)))
            RETURNING id
            """,
            {"child": str(child_id), "ref": ref, "code": code, "occurrence": occurrence},
        )
        for row in cur.fetchall():
            _log_change(cur, str(child_id), user_id, row["id"], "delete", {"id": ref})


def get_child_plans(conn: Connection, child_id: UUID) -> dict[str, bool]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT v.code, p.included FROM health.child_vaccine_plans p
            JOIN health.vaccines v ON v.id = p.vaccine_id
            WHERE p.child_id = %s
            """,
            (str(child_id),),
        )
        return {row["code"]: row["included"] for row in cur.fetchall()}


def save_child_plans(
    conn: Connection, child_id: UUID, user_id: UUID, plans: dict[str, bool | None]
) -> dict[str, bool]:
    """Bật / tắt theo dõi vắc xin cho bé. Giá trị null = về mặc định."""
    with conn, conn.cursor() as cur:
        cur.execute("SELECT code, id FROM health.vaccines WHERE code = ANY(%s)", (list(plans),))
        ids = {row["code"]: row["id"] for row in cur.fetchall()}
        unknown = sorted(set(plans) - ids.keys())
        if unknown:
            raise HTTPException(422, f"Vắc xin không tồn tại: {', '.join(unknown)}")
        for code, included in plans.items():
            if included is None:
                cur.execute(
                    "DELETE FROM health.child_vaccine_plans WHERE child_id = %s AND vaccine_id = %s",
                    (str(child_id), ids[code]),
                )
            else:
                cur.execute(
                    """
                    INSERT INTO health.child_vaccine_plans (child_id, vaccine_id, included, updated_by)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (child_id, vaccine_id) DO UPDATE
                      SET included = EXCLUDED.included, updated_by = EXCLUDED.updated_by
                    """,
                    (str(child_id), ids[code], included, str(user_id)),
                )
        _log_change(cur, str(child_id), user_id, None, "update", {"plans": plans},
                    entity_type="child_vaccine_plan")
    return get_child_plans(conn, child_id)


def _log_change(cur, child_id: str, user_id: UUID, entity_id, action: str, changes: dict,
                entity_type: str = "child_vaccination") -> None:
    cur.execute(
        """
        INSERT INTO child.child_data_change_logs
          (child_id, user_id, data_scope, entity_type, entity_id, action, changes)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (child_id, str(user_id), SCOPE, entity_type, entity_id and str(entity_id), action,
         json.dumps(changes)),
    )


# ---------------------------------------------------------------------
# Web admin: danh mục vắc xin, sản phẩm & lịch tiêm
# ---------------------------------------------------------------------
_VACCINE_SELECT = """
    SELECT v.id, v.code, v.name, v.disease, v.is_mandatory, v.description, v.is_active,
           v.choice_group, v.choice_option, v.choice_label, v.choice_default, v.sort_order,
           (SELECT count(*) FROM health.vaccine_schedules s WHERE s.vaccine_id = v.id)::int
             AS schedule_count
    FROM health.vaccines v
"""

_PRODUCT_SELECT = """
    SELECT p.id, p.vaccine_id, v.name AS vaccine_name, p.code, p.name, p.origin, p.dose_count,
           p.note, p.is_active,
           (SELECT count(*) FROM health.child_vaccinations cv WHERE cv.product_id = p.id)::int
             AS record_count
    FROM health.vaccine_products p
    JOIN health.vaccines v ON v.id = p.vaccine_id
"""

_SCHEDULE_SELECT = """
    SELECT s.id, s.vaccine_id, v.name AS vaccine_name, s.code, s.dose_number, s.dose_label,
           s.age_weeks, s.age_months, s.offset_days, s.age_to_days,
           s.after_schedule_id, prev.code AS after_code, s.min_interval_days,
           s.repeat_every_months, s.repeat_until_months, s.is_mandatory,
           coalesce(s.is_mandatory, v.is_mandatory) AS is_tcmr, s.note, s.is_active,
           (SELECT count(*) FROM health.child_vaccinations cv WHERE cv.schedule_id = s.id)::int
             AS record_count
    FROM health.vaccine_schedules s
    JOIN health.vaccines v ON v.id = s.vaccine_id
    LEFT JOIN health.vaccine_schedules prev ON prev.id = s.after_schedule_id
"""

_VACCINE_COLUMNS = {
    "code", "name", "disease", "is_mandatory", "description", "is_active",
    "choice_group", "choice_option", "choice_label", "choice_default", "sort_order",
}
_PRODUCT_COLUMNS = {"vaccine_id", "code", "name", "origin", "dose_count", "note", "is_active"}
_SCHEDULE_COLUMNS = {
    "vaccine_id", "code", "dose_number", "dose_label", "age_weeks", "age_months", "offset_days",
    "age_to_days", "after_schedule_id", "min_interval_days", "repeat_every_months",
    "repeat_until_months", "is_mandatory", "note", "is_active",
}


def _age_from_days(data: dict) -> int:
    weeks = data.get("age_weeks")
    return weeks * 7 if weeks is not None else data["age_months"] * 30 + data["offset_days"]


def _one(cur, sql: str, params) -> dict:
    cur.execute(sql, params)
    row = cur.fetchone()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy")
    return row


def _integrity(error: Exception) -> HTTPException:
    if isinstance(error, errors.UniqueViolation):
        return HTTPException(status.HTTP_409_CONFLICT, "Mã hoặc số mũi đã tồn tại")
    if isinstance(error, errors.ForeignKeyViolation):
        return HTTPException(status.HTTP_409_CONFLICT, "Đang được sử dụng hoặc tham chiếu không tồn tại")
    return HTTPException(422, "Dữ liệu không hợp lệ")


def _audit(cur, role: str, action: str, entity_type: str, entity_id, before, after) -> None:
    # Chưa có admin_user_id thật (DEV_AUTH) — ghi vai trò vào after_data để truy vết
    cur.execute(
        """
        INSERT INTO admin.admin_audit_logs (action, entity_type, entity_id, before_data, after_data)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            action, entity_type, str(entity_id),
            json.dumps(before, default=str) if before else None,
            json.dumps({**(after or {}), "_actor_role": role}, default=str),
        ),
    )


def _create(conn, role, entity_type, table, select_sql, data: dict) -> dict:
    try:
        with conn, conn.cursor() as cur:
            columns = ", ".join(data)
            placeholders = ", ".join(f"%({key})s" for key in data)
            cur.execute(f"INSERT INTO {table} ({columns}) VALUES ({placeholders}) RETURNING id", data)
            new_id = cur.fetchone()["id"]
            _audit(cur, role, "create", entity_type, new_id, None, data)
            return _one(cur, select_sql, (new_id,))
    except (errors.IntegrityError, errors.CheckViolation) as error:
        raise _integrity(error) from None


def _update(conn, role, entity_type, table, allowed, select_sql, entity_id, changes: dict) -> dict:
    changes = {key: value for key, value in changes.items() if key in allowed}
    try:
        with conn, conn.cursor() as cur:
            before = _one(cur, select_sql, (entity_id,))
            if not changes:
                return before
            assignments = [f"{key} = %({key})s" for key in changes]
            if table == "health.vaccine_schedules" and changes.keys() & {"age_weeks", "age_months", "offset_days"}:
                merged = {key: changes.get(key, before[key]) for key in ("age_weeks", "age_months", "offset_days")}
                assignments.append("age_from_days = %(_age_from_days)s")
                changes["_age_from_days"] = _age_from_days(merged)
            cur.execute(
                f"UPDATE {table} SET {', '.join(assignments)} WHERE id = %(_id)s",
                {**changes, "_id": entity_id},
            )
            after = _one(cur, select_sql, (entity_id,))
            _audit(cur, role, "update", entity_type, entity_id, before, after)
            return after
    except (errors.IntegrityError, errors.CheckViolation) as error:
        raise _integrity(error) from None


def _check_after(conn, vaccine_id: int, after_id: int | None, self_id: int | None = None) -> None:
    """Mũi trước phải cùng vắc xin và không tạo vòng."""
    if after_id is None:
        return
    with conn.cursor() as cur:
        seen = {self_id}
        current = after_id
        while current is not None:
            if current in seen:
                raise HTTPException(422, "Mũi trước tạo thành vòng lặp")
            seen.add(current)
            cur.execute(
                "SELECT vaccine_id, after_schedule_id FROM health.vaccine_schedules WHERE id = %s",
                (current,),
            )
            row = cur.fetchone()
            if row is None or row["vaccine_id"] != vaccine_id:
                raise HTTPException(422, "Mũi trước phải thuộc cùng vắc xin")
            current = row["after_schedule_id"]


def admin_list_vaccines(conn: Connection) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(_VACCINE_SELECT + " ORDER BY v.is_active DESC, v.sort_order, v.name")
        return cur.fetchall()


def admin_create_vaccine(conn: Connection, role: str, body: AdminVaccineCreate) -> dict:
    return _create(conn, role, "vaccine", "health.vaccines", _VACCINE_SELECT + " WHERE v.id = %s",
                   body.model_dump())


def admin_update_vaccine(conn: Connection, role: str, vaccine_id: int, body: AdminVaccineUpdate) -> dict:
    return _update(conn, role, "vaccine", "health.vaccines", _VACCINE_COLUMNS,
                   _VACCINE_SELECT + " WHERE v.id = %s", vaccine_id,
                   body.model_dump(exclude_unset=True))


def admin_list_products(conn: Connection) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(_PRODUCT_SELECT + " ORDER BY v.sort_order, p.id")
        return cur.fetchall()


def admin_create_product(conn: Connection, role: str, body: AdminProductCreate) -> dict:
    return _create(conn, role, "vaccine_product", "health.vaccine_products",
                   _PRODUCT_SELECT + " WHERE p.id = %s", body.model_dump())


def admin_update_product(conn: Connection, role: str, product_id: int, body: AdminProductUpdate) -> dict:
    return _update(conn, role, "vaccine_product", "health.vaccine_products", _PRODUCT_COLUMNS,
                   _PRODUCT_SELECT + " WHERE p.id = %s", product_id,
                   body.model_dump(exclude_unset=True))


def admin_list_schedules(conn: Connection) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(_SCHEDULE_SELECT + " ORDER BY s.age_from_days, v.sort_order, s.dose_number")
        return cur.fetchall()


def admin_create_schedule(conn: Connection, role: str, body: AdminScheduleCreate) -> dict:
    data = body.model_dump()
    _check_after(conn, data["vaccine_id"], data["after_schedule_id"])
    data["age_from_days"] = _age_from_days(data)
    return _create(conn, role, "vaccine_schedule", "health.vaccine_schedules",
                   _SCHEDULE_SELECT + " WHERE s.id = %s", data)


def admin_update_schedule(conn: Connection, role: str, schedule_id: int, body: AdminScheduleUpdate) -> dict:
    changes = body.model_dump(exclude_unset=True)
    if changes.get("age_weeks") is not None:
        changes["age_months"], changes["offset_days"] = divmod(changes["age_weeks"] * 7, 30)
    if "after_schedule_id" in changes:
        with conn.cursor() as cur:
            current = _one(cur, "SELECT vaccine_id FROM health.vaccine_schedules WHERE id = %s",
                           (schedule_id,))
        _check_after(conn, current["vaccine_id"], changes["after_schedule_id"], schedule_id)
    return _update(conn, role, "vaccine_schedule", "health.vaccine_schedules", _SCHEDULE_COLUMNS,
                   _SCHEDULE_SELECT + " WHERE s.id = %s", schedule_id, changes)


def admin_delete_schedule(conn: Connection, role: str, schedule_id: int) -> None:
    try:
        with conn, conn.cursor() as cur:
            before = _one(cur, _SCHEDULE_SELECT + " WHERE s.id = %s", (schedule_id,))
            if before["record_count"] > 0:
                raise HTTPException(
                    status.HTTP_409_CONFLICT,
                    "Mũi này đã có trong sổ tiêm của trẻ — hãy ẩn thay vì xóa",
                )
            cur.execute("DELETE FROM health.vaccine_schedules WHERE id = %s", (schedule_id,))
            _audit(cur, role, "delete", "vaccine_schedule", schedule_id, before, None)
    except errors.ForeignKeyViolation:
        raise HTTPException(status.HTTP_409_CONFLICT, "Mũi khác đang tính từ mũi này — sửa mũi đó trước") from None


# ---------------------------------------------------------------------
# Web admin: mũi tiêm ngoài lịch (phụ huynh tự thêm) — thống kê ẩn danh
# ---------------------------------------------------------------------
def admin_custom_dose_report(conn: Connection) -> dict:
    """Gộp mũi tự thêm theo tên để admin xem lịch chuẩn có đang thiếu vắc xin nào.

    Mọi mũi đều hiện (đã tiêm lẫn đang hẹn, kể cả chỉ 1 bé), mới nhất lên đầu.
    Không trả thông tin định danh bé / phụ huynh.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            WITH custom AS (
                SELECT lower(btrim(regexp_replace(cv.custom_name, '\s+', ' ', 'g'))) AS key,
                       btrim(regexp_replace(cv.custom_name, '\s+', ' ', 'g')) AS name,
                       nullif(btrim(cv.custom_disease), '') AS prevents,
                       cv.child_id, cv.status, cv.created_at
                FROM health.child_vaccinations cv
                JOIN child.children c ON c.id = cv.child_id AND c.deleted_at IS NULL
                WHERE cv.schedule_id IS NULL
            ),
            grouped AS (
                SELECT key,
                       mode() WITHIN GROUP (ORDER BY name) AS name,
                       mode() WITHIN GROUP (ORDER BY prevents) AS prevents,
                       count(DISTINCT child_id)::int AS child_count,
                       count(*)::int AS dose_count,
                       count(*) FILTER (WHERE status = 'done')::int AS given_count,
                       count(*) FILTER (WHERE status = 'planned')::int AS planned_count,
                       min(created_at) AS first_recorded_at,
                       max(created_at) AS last_recorded_at
                FROM custom GROUP BY key
            ),
            catalog AS (
                SELECT lower(name) AS key, code FROM health.vaccines
                UNION
                SELECT lower(p.name), v.code FROM health.vaccine_products p
                JOIN health.vaccines v ON v.id = p.vaccine_id
            )
            SELECT g.*, (SELECT min(code) FROM catalog k WHERE k.key = g.key) AS catalog_vaccine,
                   (SELECT count(DISTINCT child_id) FROM custom)::int AS total_children
            FROM grouped g
            ORDER BY g.last_recorded_at DESC, g.key
            """
        )
        rows = cur.fetchall()
    return {
        "items": rows,
        "total_children": rows[0]["total_children"] if rows else 0,
        "total_doses": sum(row["dose_count"] for row in rows),
    }
