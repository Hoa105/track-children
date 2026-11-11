"""Đánh giá tổng hợp nhiều nhận xét video của một bé (app/reviews). JSON camelCase."""

import datetime as dt
from uuid import UUID

from pydantic import Field

from app.schemas.insight import ActivityGroup, CamelModel

MIN_INSIGHTS = 2
MAX_INSIGHTS = 60  # mọi video trong khoảng thời gian ba mẹ chọn


class NewReview(CamelModel):
    child_id: UUID
    requested_by: UUID
    insight_ids: list[UUID] = Field(min_length=MIN_INSIGHTS, max_length=MAX_INSIGHTS)


class ReviewResult(CamelModel):
    """Đầu ra của AI — thay đổi qua các lần quay, không chấm điểm.

    Năm mục hiển thị cho ba mẹ: tổng quan, tiến bộ theo thời gian, điểm mạnh /
    cần hỗ trợ, dấu hiệu cần chú ý, kế hoạch luyện tập. Trường mới đều có mặc
    định để đọc được các đánh giá cũ (progress-review-v2).
    """

    # 1. Tổng quan
    summary: str
    activities: list[str] = Field(default_factory=list)  # service điền, không do AI viết
    skills_done: list[str] = Field(default_factory=list)  # kỹ năng bé đã làm được
    skills_improving: list[str] = Field(default_factory=list)
    stage: str = ""  # giai đoạn phát triển, mô tả nhẹ nhàng, không gán nhãn
    # 2. Tiến bộ theo thời gian
    progress: list[str] = Field(default_factory=list)  # thay đổi qua các lần quay / theo tháng
    independence: str = ""  # từ cần hỗ trợ → tự thực hiện
    pace: str = ""  # tốc độ tiến bộ có thay đổi không
    # 3. Điểm mạnh và kỹ năng cần hỗ trợ
    strengths: list[str] = Field(default_factory=list)
    challenges: list[str] = Field(default_factory=list)
    keep_practicing: list[str] = Field(default_factory=list)  # kỹ năng cần luyện thêm
    # 5. Dấu hiệu cần chú ý
    repeated_patterns: list[str] = Field(default_factory=list)
    not_yet_seen: list[str] = Field(default_factory=list)  # kỹ năng chưa thấy trong video
    behavior_changes: list[str] = Field(default_factory=list)
    see_specialist: bool = False
    specialist_note: str = ""
    # 6. Kế hoạch chăm sóc và luyện tập
    next_steps: list[str] = Field(default_factory=list)  # hoạt động nên làm tuần tới
    priority_skills: list[str] = Field(default_factory=list)
    parent_tips: list[str] = Field(default_factory=list)  # cách ba mẹ tương tác với bé
    next_recording: str = ""  # khi nào nên quay video tiếp theo


class MetricPoint(CamelModel):
    insight_id: UUID
    at: dt.datetime
    value: float


class MetricTrend(CamelModel):
    key: str
    label: str
    unit: str
    points: list[MetricPoint]
    change: float | None = None  # lần cuối − lần đầu; None khi chỉ có một điểm


class Review(CamelModel):
    id: UUID
    child_id: UUID
    activity_ref: str | None = None
    activity_group: ActivityGroup | None = None  # None khi gộp nhiều nhóm hoạt động
    activity_title: str
    insight_ids: list[UUID]
    period_from: dt.datetime
    period_to: dt.datetime
    result: ReviewResult
    metrics: list[MetricTrend] = Field(default_factory=list)
    created_at: dt.datetime
