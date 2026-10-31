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
