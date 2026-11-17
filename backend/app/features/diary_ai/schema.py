"""Bodies for diary video insights. camelCase on the wire, like the other mobile APIs."""

import datetime as dt
from typing import Literal
from uuid import UUID

from pydantic import Field

from app.features.vaccination.schema import CamelModel

ActivityGroup = Literal[
    "gross_motor", "fine_motor", "language", "cognitive_social", "music", "storytelling"
]


class GuideSection(CamelModel):
    title: str = Field(max_length=120)
    text: str = Field(max_length=2000)


class ActivityInfo(CamelModel):
    """Hoạt động mobile gửi kèm video (danh mục hoạt động hiện nằm trên mobile)."""

    id: str = Field(min_length=1, max_length=64)
    title: str = Field(min_length=1, max_length=300)
    group: ActivityGroup
    age_from_months: int = Field(ge=0, le=120)
    age_to_months: int = Field(ge=0, le=120)
    guide: list[GuideSection] = Field(default_factory=list, max_length=12)


class InsightResult(CamelModel):
    can_assess: bool
    video_issue: str = ""
    observations: list[str] = []
    comment: str = ""
    positives: list[str] = []
    next_steps: list[str] = []
    watch_signs: list[str] = []
    see_specialist: bool = False
    specialist_note: str = ""


class EvidenceMetric(CamelModel):
    key: str
    label: str
    value: float
    unit: str


class Evidence(CamelModel):
    available: bool
    reason: str = ""
    detection_ratio: float | None = None
    metrics: list[EvidenceMetric] = []


class VideoInsight(CamelModel):
    id: UUID
    activity_ref: str
    status: Literal["pending", "running", "done", "rejected", "failed"]
    message: str | None = None  # lý do cho phụ huynh khi rejected / failed
    result: InsightResult | None = None
    evidence: Evidence | None = None
    created_at: dt.datetime
    finished_at: dt.datetime | None = None


# ---------------------------------------------------------------------
# Đánh giá tổng hợp nhiều video (theo dõi lâu dài)
# ---------------------------------------------------------------------
class NewProgressReview(CamelModel):
    """Các video đã phân tích xong (một hoặc nhiều hoạt động, vd. mọi video trong
    khoảng thời gian ba mẹ chọn)."""

    insight_ids: list[UUID] = Field(min_length=2, max_length=60)


class ProgressReviewResult(CamelModel):
    """Năm mục cho ba mẹ (ai-service app/schemas/review.py ReviewResult)."""

    # 1. Tổng quan
    summary: str
    activities: list[str] = []
    skills_done: list[str] = []
    skills_improving: list[str] = []
    stage: str = ""
    # 2. Tiến bộ theo thời gian
    progress: list[str] = []
    independence: str = ""
    pace: str = ""
    # 3. Điểm mạnh và kỹ năng cần hỗ trợ
    strengths: list[str] = []
    challenges: list[str] = []
    keep_practicing: list[str] = []
    # 5. Dấu hiệu cần chú ý
    repeated_patterns: list[str] = []
    not_yet_seen: list[str] = []
    behavior_changes: list[str] = []
    see_specialist: bool = False
    specialist_note: str = ""
    # 6. Kế hoạch chăm sóc và luyện tập
    next_steps: list[str] = []
    priority_skills: list[str] = []
    parent_tips: list[str] = []
    next_recording: str = ""


class MetricPoint(CamelModel):
    insight_id: UUID
    at: dt.datetime
    value: float


class MetricTrend(CamelModel):
    key: str
    label: str
    unit: str
    points: list[MetricPoint]
    change: float | None = None


class ProgressReview(CamelModel):
    id: UUID
    activity_ref: str | None = None
    activity_group: ActivityGroup | None = None  # None khi gộp nhiều nhóm hoạt động
    activity_title: str
    insight_ids: list[UUID]
    period_from: dt.datetime
    period_to: dt.datetime
    result: ProgressReviewResult
    metrics: list[MetricTrend] = []
    created_at: dt.datetime
