"""Bodies of the video-insight API. JSON fields are camelCase (backend passes them to mobile)."""

import datetime as dt
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

ActivityGroup = Literal[
    "gross_motor", "fine_motor", "language", "cognitive_social", "music", "storytelling"
]
MOTOR_GROUPS: frozenset[str] = frozenset({"gross_motor", "fine_motor"})
InsightStatus = Literal["pending", "running", "done", "rejected", "failed"]


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


# ---------------------------------------------------------------------
# Context backend gửi kèm video
# ---------------------------------------------------------------------
class GuideSection(CamelModel):
    title: str = Field(max_length=120)
    text: str = Field(max_length=2000)


class ActivityContext(CamelModel):
    id: str = Field(min_length=1, max_length=64)
    title: str = Field(min_length=1, max_length=300)
    group: ActivityGroup
    age_from_months: int = Field(ge=0, le=120)
    age_to_months: int = Field(ge=0, le=120)
    guide: list[GuideSection] = Field(default_factory=list, max_length=12)


class GroupCriteria(CamelModel):
    name: str
    focus: list[str]  # điều cần quan sát
    avoid: list[str] = Field(default_factory=list)  # điều không được kết luận từ video


class InsightContext(CamelModel):
    activity: ActivityContext
    criteria: GroupCriteria
    child_age_months: int = Field(ge=0, le=120)
    parent_note: str = Field(default="", max_length=1000)
    # Giai đoạn 2: khóa số đo cần tính cho hoạt động (xem app/pose/evidence.py)
    metrics: list[str] = Field(default_factory=list, max_length=12)


class NewInsight(CamelModel):
    child_id: UUID
    requested_by: UUID
    consented_at: dt.datetime
    context: InsightContext


# ---------------------------------------------------------------------
# Kết quả
# ---------------------------------------------------------------------
class InsightResult(CamelModel):
    """Đầu ra của AI — quan sát và gợi ý, không chấm điểm."""

    can_assess: bool
    video_issue: str = ""
    observations: list[str] = Field(default_factory=list)
    comment: str = ""
    positives: list[str] = Field(default_factory=list)
    next_steps: list[str] = Field(default_factory=list)
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
    metrics: list[EvidenceMetric] = Field(default_factory=list)


class Insight(CamelModel):
    id: UUID
    child_id: UUID
    activity_ref: str
    status: InsightStatus
    message: str | None = None
    result: InsightResult | None = None
    evidence: Evidence | None = None
    created_at: dt.datetime
    finished_at: dt.datetime | None = None
