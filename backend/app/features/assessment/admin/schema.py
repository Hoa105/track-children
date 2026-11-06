from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, str_strip_whitespace=True)


QuestionSetStatus = Literal["draft", "in_review", "published", "archived"]
ContentKind = Literal["skill", "advice"]


class AdminQuestionSet(CamelModel):
    id: UUID
    code: str
    age_months: int
    version: str
    locale: str
    source_name: str
    status: QuestionSetStatus
    content_count: int
    published_count: int
    visible_question_count: int = 0
    created_at: datetime
    updated_at: datetime
    is_active: bool = False
    deleted_at: datetime | None = None


class AdminQuestionSetCreate(CamelModel):
    code: str = Field(pattern=r"^[a-z0-9][a-z0-9_-]{1,60}$")
    age_months: Literal[2,4,6,9,12,15,18,24,30,36,48,60]
    version: str = Field(min_length=1, max_length=40)
    locale: str = Field(default="vi-VN", min_length=2, max_length=16)
    source_name: str = Field(default="CDC Developmental Milestones", min_length=1, max_length=200)


class AdminQuestionSetUpdate(CamelModel):
    source_name: str | None = Field(default=None, min_length=1, max_length=200)


class AdminContentRow(CamelModel):
    id: UUID
    kind: ContentKind
    stable_code: str
    question_set_id: UUID | None
    source_domain: str | None
    app_domain: str | None
    order_index: int | None
    current_revision: int
    published_revision: int | None
    is_active: bool
    deleted_at: datetime | None
    payload: dict[str, Any]
    source_refs: list[dict[str, Any]] = Field(default_factory=list)
    revision_created_at: datetime
    updated_at: datetime


class AdminContentRevision(CamelModel):
    content_item_id: UUID
    revision: int
    locale: str
    payload: dict[str, Any]
    source_refs: list[dict[str, Any]]
    created_at: datetime


class AdminContentCreate(CamelModel):
    kind: ContentKind = "skill"
    stable_code: str = Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_-]{1,80}$")
    source_domain: str | None = None
    app_domain: str | None = None
    order_index: int = Field(ge=0, le=1000)
    payload: dict[str, Any] = Field(default_factory=dict)
    source_refs: list[dict[str, Any]] = Field(default_factory=list)


class AdminContentRevisionCreate(CamelModel):
    expected_revision: int = Field(ge=1)
    payload: dict[str, Any]
    source_refs: list[dict[str, Any]] = Field(default_factory=list)
    app_domain: Literal['gross_motor','fine_motor','language_communication','cognitive','social_emotional'] | None = None


class AvailabilityUpdate(CamelModel):
    is_active: bool


class QuestionOrder(CamelModel):
    content_ids: list[UUID]


class PublishRevision(CamelModel):
    expected_revision: int = Field(ge=1)


ReviewType = Literal["medical", "language", "qa", "media_rights"]
ReviewDecision = Literal["approved", "rejected"]


class AdminReviewRow(CamelModel):
    content_item_id: UUID
    stable_code: str
    kind: ContentKind
    question_set_id: UUID | None
    revision: int
    payload: dict[str, Any]
    source_refs: list[dict[str, Any]]
    reviews: dict[str, dict[str, Any]]
    created_at: datetime


class AdminReviewCreate(CamelModel):
    revision: int = Field(ge=1)
    review_type: ReviewType
    decision: ReviewDecision
    evidence_ref: str | None = Field(default=None, max_length=500)
    note: str | None = Field(default=None, max_length=2000)

    @model_validator(mode="after")
    def rejected_needs_note(self) -> "AdminReviewCreate":
        if self.decision == "rejected" and not (self.note or "").strip():
            raise ValueError("Review bị từ chối phải có ghi chú")
        return self


class AdminPublishResult(CamelModel):
    question_set_id: UUID
    status: QuestionSetStatus
    published_revision_count: int
