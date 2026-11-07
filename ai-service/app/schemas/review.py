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
    """Đầu ra của AI — thay đổi qua các lần quay, không chấm điểm."""

    summary: str
    progress: list[str] = Field(default_factory=list)  # thay đổi tích cực thấy được
    keep_practicing: list[str] = Field(default_factory=list)  # điều nên tiếp tục cùng bé luyện
    next_steps: list[str] = Field(default_factory=list)
    see_specialist: bool = False
    specialist_note: str = ""


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
