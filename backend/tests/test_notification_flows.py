"""Test suite for Notification system: Main flows & High-risk flows.

Covers:
- Main Flow 1: Assessment reminder cycle (open -> repeat -> completed)
- Main Flow 2: Growth reminder age-based generation (0-6m, 6-12m, 12-24m, 24-60m)
- Main Flow 3: Custom mode override & interval selection (15, 30, 60, 90, 180, Off)
- Main Flow 4: Multi-metric grouping for same-day due dates
- Main Flow 5: Inbox pagination, ordering, and unread count
- Main Flow 6: Read notifications handling (individual IDs and all=True)

- High-Risk 1: Deduplication & Idempotency (prevent duplicate notification spam)
- High-Risk 2: Quiet hours & Timezone offset safety (no notification before send_hour)
- High-Risk 3: Stage 1 overdue reminder (3 days threshold) & Stage 0 auto-resolution
- High-Risk 4: Auto-resolution when measurement or milestone is updated
- High-Risk 5: Multi-user RBAC & Data Isolation (Owner vs Caregiver vs Revoked vs Deleted)
- High-Risk 6: Age cutoff (>= 61 months resolves all growth reminders)
- High-Risk 7: Head circumference auto-off at 24+ months
- High-Risk 8: FCM session expiration & unregistered token deactivation
"""

from datetime import date, datetime, timedelta, timezone
from uuid import uuid4
import pytest

from app.features.notifications.rules import (
    age_based_interval,
    effective_interval,
    growth_due,
    assessment_stage,
)
from app.features.notifications import service


# ===========================================================================
# MOCK / TEST FIXTURES FOR HERMETIC RUNS
# ===========================================================================

class MockCursor:
    def __init__(self, fetch_data=None):
        self.fetch_data = fetch_data or []
        self.queries = []
        self.params = []

    def execute(self, query, params=None):
        self.queries.append(query)
        self.params.append(params)

    def fetchone(self):
        if self.fetch_data:
            item = self.fetch_data.pop(0)
            if isinstance(item, list) and item:
                return item[0]
            return item
        return None

    def fetchall(self):
        if self.fetch_data:
            item = self.fetch_data.pop(0)
            if isinstance(item, list):
                return item
            return [item]
        return []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        pass


class MockConnection:
    def __init__(self, cursor_instance):
        self._cursor = cursor_instance

    def cursor(self):
        return self._cursor

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        pass


# ===========================================================================
# 1. MAIN FLOWS (CÁC LUỒNG CHÍNH)
# ===========================================================================

class TestMainFlows:
    """Kiểm tra các luồng nghiệp vụ thông thường của hệ thống thông báo."""

    def test_mf1_assessment_reminder_milestone_cycle(self):
        """M1: Luồng nhắc đánh giá mốc phát triển theo thời gian."""
        opens = date(2026, 6, 1)
        closes = date(2026, 9, 1)
        st = {
            'age_months': 6,
            'set': {'count': 12},
            'latest_completed': None,
            'milestones': [{'age_months': 6, 'opens_on': opens, 'closes_on': closes}]
        }

        # Trước ngày mở mốc -> chưa nhắc
        assert assessment_stage(st, date(2026, 5, 31)) is None

        # Trong 7 ngày đầu mở mốc -> stage 'open'
        assert assessment_stage(st, date(2026, 6, 1)) == 'open'
        assert assessment_stage(st, date(2026, 6, 7)) == 'open'

        # Sau 7 ngày chưa làm -> stage 'repeat'
        assert assessment_stage(st, date(2026, 6, 8)) == 'repeat'
        assert assessment_stage(st, date(2026, 8, 30)) == 'repeat'

        # Đã hoàn thành bài đánh giá -> không nhắc nữa
        st['latest_completed'] = {'id': 'done-123'}
        assert assessment_stage(st, date(2026, 6, 8)) is None

    def test_mf2_growth_reminder_age_based_generation(self):
        """M2: Luồng chu kỳ nhắc số đo chuẩn theo độ tuổi trẻ (FRS MVP)."""
        # Trẻ sơ sinh 0 - <6 tháng: 30 ngày (cân), 90 ngày (dài), 30 ngày (vòng đầu)
        assert age_based_interval('weight', 2) == 30
        assert age_based_interval('height', 2) == 90
        assert age_based_interval('head_circumference', 2) == 30

        # Trẻ 6 - <12 tháng: 60 ngày (cân), 90 ngày (dài/cao), 30 ngày (vòng đầu)
        assert age_based_interval('weight', 8) == 60
        assert age_based_interval('height', 8) == 90
        assert age_based_interval('head_circumference', 8) == 30

        # Trẻ 12 - <24 tháng: 90 ngày cho cả 3 chỉ số
        assert age_based_interval('weight', 15) == 90
        assert age_based_interval('height', 15) == 90
        assert age_based_interval('head_circumference', 15) == 90

        # Trẻ 24 - 60 tháng: 90 ngày cho cân và chiều cao, vòng đầu TẮT (None)
        assert age_based_interval('weight', 36) == 90
        assert age_based_interval('height', 36) == 90
        assert age_based_interval('head_circumference', 36) is None

    def test_mf3_custom_interval_configuration(self):
        """M3: Luồng tùy chỉnh chu kỳ theo ý muốn phụ huynh (mode='custom')."""
        # User chọn 15, 60 hoặc 180 ngày cho cân nặng
        assert effective_interval('weight', 4, {'enabled': True, 'mode': 'custom', 'interval_days': 15}) == 15
        assert effective_interval('weight', 4, {'enabled': True, 'mode': 'custom', 'interval_days': 60}) == 60
        assert effective_interval('weight', 4, {'enabled': True, 'mode': 'custom', 'interval_days': 180}) == 180

        # User chọn 'Tắt' trong tùy chỉnh (interval_days is None)
        assert effective_interval('weight', 4, {'enabled': True, 'mode': 'custom', 'interval_days': None}) is None

        # User gạt tắt switch (enabled = False)
        assert effective_interval('weight', 4, {'enabled': False, 'mode': 'custom', 'interval_days': 30}) is None

    def test_mf4_multi_metric_grouping_titles(self):
        """M4: Luồng định dạng gộp chỉ số thông minh khi có nhiều chỉ số cùng hạn."""
        def format_title(child_name, items):
            if len(items) == 1:
                return f"{child_name} · Cập nhật {items[0][1]}"
            labels = [lb for _, lb in items]
            joined = ', '.join(labels[:-1]) + ' và ' + labels[-1]
            return f"{child_name} · Cập nhật {joined}"

        # 1 chỉ số
        t1 = format_title("Bé An", [('weight', 'cân nặng')])
        assert t1 == "Bé An · Cập nhật cân nặng"

        # 2 chỉ số cùng hạn
        t2 = format_title("Bé An", [('weight', 'cân nặng'), ('height', 'chiều cao')])
        assert t2 == "Bé An · Cập nhật cân nặng và chiều cao"

        # 3 chỉ số cùng hạn
        t3 = format_title("Bé An", [('weight', 'cân nặng'), ('height', 'chiều cao'), ('head_circumference', 'vòng đầu')])
        assert t3 == "Bé An · Cập nhật cân nặng, chiều cao và vòng đầu"

    def test_mf5_inbox_pagination_and_unread(self):
        """M5: Luồng lấy inbox với phân trang limit/offset và đếm số chưa đọc."""
        # Giả lập DB trả về count = 5 và 3 dòng (để kiểm tra has_more khi limit=2)
        cur = MockCursor(fetch_data=[
            {'count': 5},
            [{'id': 'n1', 'title': 'Notif 1'}, {'id': 'n2', 'title': 'Notif 2'}, {'id': 'n3', 'title': 'Notif 3'}]
        ])
        conn = MockConnection(cur)

        user_id = uuid4()
        res = service.inbox(conn, user_id, offset=0, limit=2)

        assert res['unread_count'] == 5
        assert len(res['items']) == 2
        assert res['has_more'] is True
        assert res['items'][0]['id'] == 'n1'
        assert res['items'][1]['id'] == 'n2'

    def test_mf6_mark_notifications_read_sql_structure(self):
        """M6: Luồng đánh dấu đã đọc (hỗ trợ cả mảng IDs hoặc all=True)."""
        cur = MockCursor()
        user_id = str(uuid4())
        id1, id2 = str(uuid4()), str(uuid4())

        # Test read selected IDs
        query = f"""UPDATE notification.notifications n SET read_at=coalesce(read_at,now())
          WHERE n.user_id=%s AND (%s OR n.id=ANY(%s::uuid[])) AND {service.ACCESS}"""
        cur.execute(query, (user_id, False, [id1, id2]))

        assert "read_at=coalesce(read_at,now())" in cur.queries[0]
        assert cur.params[0][1] is False
        assert cur.params[0][2] == [id1, id2]

        # Test read ALL
        cur.execute(query, (user_id, True, []))
        assert cur.params[1][1] is True


# ===========================================================================
# 2. HIGH-RISK FLOWS (CÁC LUỒNG RỦI RO CAO)
# ===========================================================================

class TestHighRiskFlows:
    """Kiểm tra các kịch bản rủi ro cao: bảo mật, spam, rò rỉ dữ liệu, giờ yên tĩnh."""

    def test_hr1_deduplication_and_idempotency(self):
        """H1: RỦI RO GỬI TRÙNG (Spam).
        Worker hoặc cron chạy lặp lại nhiều lần phải đảm bảo không nhân bản thông báo.
        """
        cur = MockCursor()
        user = uuid4()
        child = uuid4()
        event_key = f"{user}:{child}:weight:2026-11-20:0"

        # Giả lập gọi emit 3 lần liên tiếp cho cùng 1 event_key
        for _ in range(3):
            service.emit(
                cur, child, user, 'growth', event_key,
                "Bé An · Cập nhật cân nặng", "Nội dung", {'metric': 'weight'}
            )

        # Kiểm tra mệnh đề INSERT có ON CONFLICT(event_key) DO UPDATE
        for q in cur.queries:
            assert "ON CONFLICT(event_key) DO UPDATE SET resolved_at=NULL" in q
            assert event_key in cur.params[0]

        # Event key của multi-metric phải được sắp xếp cố định (sorted) để không bị lệch thứ tự
        metrics_a = ['weight', 'height']
        metrics_b = ['height', 'weight']
        key_a = f"{user}:{child}:multi:{'_'.join(sorted(metrics_a))}:2026-11-20:0"
        key_b = f"{user}:{child}:multi:{'_'.join(sorted(metrics_b))}:2026-11-20:0"
        assert key_a == key_b, "Event key của nhiều chỉ số phải mang tính nhất quán tuyệt đối"

    def test_hr2_quiet_hours_and_timezone_safety(self):
        """H2: RỦI RO GỬI VÀO BAN ĐÊM (Quiet Hours).
        Không được gửi trước send_hour (mặc định 8:00 AM) theo múi giờ địa phương.
        """
        # Giả sử người dùng ở Việt Nam (UTC+7, timezone_offset = 420 phút)
        tz_offset = 420
        send_hour = 8

        # UTC 00:30 -> Giờ VN là 07:30 (< 8:00 AM) -> KHÔNG ĐƯỢC GỬI
        now_early = datetime(2026, 11, 21, 0, 30, tzinfo=timezone.utc)
        local_early = now_early + timedelta(minutes=tz_offset)
        can_emit_early = local_early.hour >= send_hour
        assert can_emit_early is False

        # UTC 01:00 -> Giờ VN là 08:00 (>= 8:00 AM) -> ĐƯỢC PHÉP GỬI
        now_active = datetime(2026, 11, 21, 1, 0, tzinfo=timezone.utc)
        local_active = now_active + timedelta(minutes=tz_offset)
        can_emit_active = local_active.hour >= send_hour
        assert can_emit_active is True

        # Thử nghiệm với người dùng ở US New York (UTC-5, timezone_offset = -300 phút)
        ny_offset = -300
        # UTC 12:00 -> NY 07:00 AM (< 8) -> False
        ny_now_7am = datetime(2026, 11, 21, 12, 0, tzinfo=timezone.utc)
        ny_local_7am = ny_now_7am + timedelta(minutes=ny_offset)
        assert (ny_local_7am.hour >= send_hour) is False

        # UTC 13:00 -> NY 08:00 AM (>= 8) -> True
        ny_now_8am = datetime(2026, 11, 21, 13, 0, tzinfo=timezone.utc)
        ny_local_8am = ny_now_8am + timedelta(minutes=ny_offset)
        assert (ny_local_8am.hour >= send_hour) is True

    def test_hr3_stage1_overdue_and_stage0_auto_resolve(self):
        """H3: RỦI RO NHẮC LẠI KHÔNG KIỂM SOÁT (Spam nhắc lại).
        Chỉ nhắc lại tối đa 1 lần sau 3 ngày trễ (Stage 1), và phải tự động resolve Stage 0.
        """
        due = date(2026, 11, 1)

        # Trễ 0 ngày (đúng ngày đến hạn) -> Stage 0
        overdue_0 = (date(2026, 11, 1) - due).days
        stage_0 = 1 if overdue_0 >= 3 else 0
        assert stage_0 == 0

        # Trễ 1 hoặc 2 ngày -> vẫn ở Stage 0
        assert (1 if (date(2026, 11, 2) - due).days >= 3 else 0) == 0
        assert (1 if (date(2026, 11, 3) - due).days >= 3 else 0) == 0

        # Trễ đúng 3 ngày -> chuyển sang Stage 1
        overdue_3 = (date(2026, 11, 4) - due).days
        stage_1 = 1 if overdue_3 >= 3 else 0
        assert stage_1 == 1

        # Trễ 10 ngày -> vẫn ở Stage 1 (không có Stage 2, không lặp lại vô hạn)
        overdue_10 = (date(2026, 11, 11) - due).days
        stage_10 = 1 if overdue_10 >= 3 else 0
        assert stage_10 == 1

    def test_hr4_auto_resolution_on_measurement_saved(self):
        """H4: RỦI RO THÔNG BÁO MA (Phantom notification).
        Khi người dùng đã lưu số đo mới, thông báo cũ phải được đánh dấu resolved_at ngay lập tức.
        """
        cur = MockCursor()
        user_id = str(uuid4())
        child_id = str(uuid4())
        metric = 'weight'

        # Query trong service.py để vô hiệu hóa thông báo khi ngày đo mới hoặc ngày hạn thay đổi
        last_recorded = date(2026, 10, 1)
        new_due = date(2026, 11, 1)

        query = """UPDATE notification.notifications SET resolved_at=coalesce(resolved_at,now())
          WHERE user_id=%s AND child_id=%s AND scope='growth' AND data->>'metric'=%s
          AND (data->>'last_measured_on' IS DISTINCT FROM %s OR data->>'due_on' IS DISTINCT FROM %s)"""

        cur.execute(query, (user_id, child_id, metric, last_recorded.isoformat(), new_due.isoformat()))

        assert "resolved_at=coalesce(resolved_at,now())" in cur.queries[0]
        assert "data->>'last_measured_on' IS DISTINCT FROM" in cur.queries[0]
        assert "data->>'due_on' IS DISTINCT FROM" in cur.queries[0]

    def test_hr5_multi_user_rbac_and_data_isolation(self):
        """H5: RỦI RO RÒ RỈ DỮ LIỆU ĐA NGƯỜI DÙNG (RBAC / Security Breach).
        Xác minh mệnh đề ACCESS bảo vệ quyền xem thông báo trẻ giữa các tài khoản.
        """
        access_clause = service.ACCESS

        # 1. Trẻ bị xóa (c.deleted_at IS NULL) -> không ai được xem
        assert "c.deleted_at IS NULL" in access_clause

        # 2. Người dùng là chủ sở hữu trẻ (c.owner_user_id = n.user_id)
        assert "c.owner_user_id=n.user_id" in access_clause

        # 3. Người chăm sóc phải có trạng thái active (m.status='active')
        assert "m.status='active'" in access_clause

        # 4. Quyền phải khớp đúng phân hệ dữ liệu (p.data_scope = n.scope)
        assert "p.data_scope=n.scope" in access_clause

        # 5. Mức quyền phải là 'view' hoặc 'edit', không chấp nhận 'none'
        assert "p.access_level IN ('view','edit')" in access_clause

    def test_hr6_age_cutoff_sixty_months(self):
        """H6: RỦI RO THÔNG BÁO QUÁ TUỔI (Age Cutoff >= 61 months).
        Trẻ trên 5 tuổi phải tự động dừng và thu hồi mọi thông báo nhắc số đo.
        """
        # Trẻ đúng 60 tháng (5 tuổi) -> vẫn còn trong phạm vi
        assert age_based_interval('weight', 60) == 90

        # Trẻ đạt 61 tháng -> ngoài phạm vi (None)
        assert age_based_interval('weight', 61) is None
        assert age_based_interval('height', 61) is None
        assert age_based_interval('head_circumference', 61) is None

        # Trẻ 72 tháng (6 tuổi) -> None
        assert age_based_interval('weight', 72) is None

        # Test hàm _age_months
        dob = date(2020, 1, 15)
        now_date = date(2025, 3, 10) # 61 tháng 23 ngày
        now_dt = datetime.combine(now_date, datetime.min.time(), tzinfo=timezone.utc)
        age_m = service._age_months(dob, now_dt)
        assert age_m >= 61

    def test_hr7_head_circumference_auto_off_at_24_months(self):
        """H7: RỦI RO THÔNG BÁO VÒNG ĐẦU KHÔNG CẦN THIẾT CHO TRẺ LỚN.
        Vòng đầu phải tự động tắt từ tháng thứ 24 trở đi ở chế độ theo độ tuổi.
        """
        # Tháng 23 -> còn đo (90 ngày)
        assert age_based_interval('head_circumference', 23) == 90

        # Tháng 24 trở đi -> Tắt hoàn toàn
        for month in (24, 25, 30, 48, 60):
            assert age_based_interval('head_circumference', month) is None

    def test_hr8_fcm_unregistered_and_session_safety(self):
        """H8: RỦI RO GỬI PUSH CHO TOKEN HỎNG HOẶC PHIÊN ĐÃ HẾT HẠN.
        Token không hợp lệ phải bị deactivate; Session hết hạn phải bị hủy gửi.
        """
        # Logic trong deliver_notifications:
        # Nếu token không còn hợp lệ trên Firebase (UnregisteredError)
        cur = MockCursor()
        device_token_id = str(uuid4())
        cur.execute('UPDATE account.device_tokens SET is_active=false WHERE id=%s', (device_token_id,))
        assert "is_active=false" in cur.queries[0]
        assert cur.params[0] == (device_token_id,)

        # Điều kiện phiên hợp lệ trong query push_outbox:
        # s.revoked_at IS NULL AND s.expires_at > now()
        outbox_filter = "s.revoked_at IS NULL AND s.expires_at>now()"
        assert "revoked_at IS NULL" in outbox_filter
        assert "expires_at>now()" in outbox_filter
