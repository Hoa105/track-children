"""Response bodies. Field names are camelCase to match the mobile and admin clients."""

import datetime as dt
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class ActivityGroup(CamelModel):
    code: str
    name: str
    description: str | None
    emoji: str | None
    tint_hex: str | None
    activity_count: int


class ActivitySummary(CamelModel):
    """Một dòng trong danh sách hoạt động (màn danh sách / gợi ý)."""

    id: UUID
    group_code: str | None
    title: str
    summary: str | None
    age_from_months: int
    age_to_months: int
    duration_minutes: int | None
    # Đường dẫn tương đối (/static/...), client ghép với địa chỉ backend
    thumbnail_url: str | None


class ActivitySection(CamelModel):
    title: str
    body: str


class ActivityStep(CamelModel):
    number: int
    title: str | None
    instruction: str
    image_url: str | None


class ActivityMedia(CamelModel):
    media_type: str
    url: str
    caption: str | None


class ActivityProgress(CamelModel):
    """Trạng thái "Đã làm" của một hoạt động, theo từng bé."""

    activity_id: UUID
    status: str
    completed_at: dt.datetime | None


class ActivityProgressUpdate(CamelModel):
    done: bool


class ActivityDetail(ActivitySummary):
    goal: str | None
    materials: str | None
    material_items: list[str]
    needs_adult: bool
    lyrics: str | None
    # Các mục trong content (Chuẩn bị, Hướng dẫn của chuyên gia...), trừ các bước
    sections: list[ActivitySection]
    steps: list[ActivityStep]
    media: list[ActivityMedia]


# ---------------------------------------------------------------------
# Web admin (quyền activity.write)
# ---------------------------------------------------------------------
Status = Literal["draft", "published", "hidden"]
DetailKind = Literal["move", "music", "story"]
_CODE = r"^[a-z0-9_]{2,40}$"
_HEX = r"^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$"


class AdminGroup(CamelModel):
    id: int
    code: str
    name: str
    description: str | None
    emoji: str | None
    tint_hex: str | None
    detail_kind: DetailKind
    sort_order: int
    is_active: bool
    activity_count: int  # mọi trạng thái
    published_count: int


class AdminGroupUpdate(CamelModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    description: str | None = None
    emoji: str | None = Field(None, max_length=16)
    tint_hex: str | None = Field(None, pattern=_HEX)
    detail_kind: DetailKind | None = None
    sort_order: int | None = Field(None, ge=0, le=1000)
    is_active: bool | None = None


class AdminGroupCreate(AdminGroupUpdate):
    code: str = Field(pattern=_CODE)
    name: str = Field(min_length=1, max_length=100)


class AdminActivityRow(CamelModel):
    id: UUID
    title: str
    group_id: int | None
    group_name: str | None
    status: Status
    age_from_months: int
    age_to_months: int
    duration_minutes: int | None
    thumbnail_url: str | None
    step_count: int
    media_count: int
    updated_at: dt.datetime


class AdminStep(CamelModel):
    number: int
    title: str | None
    instruction: str
    image_url: str | None


class AdminMedia(CamelModel):
    id: UUID
    media_type: str
    url: str
    caption: str | None
    sort_order: int


class AdminActivity(CamelModel):
    id: UUID
    title: str
    summary: str | None
    content: str
    group_id: int | None
    status: Status
    age_from_months: int
    age_to_months: int
    duration_minutes: int | None
    materials: str | None
    material_items: list[str]
    goal: str | None
    safety_note: str | None
    needs_adult: bool
    lyrics: str | None
    thumbnail_url: str | None
    published_at: dt.datetime | None
    created_at: dt.datetime
    updated_at: dt.datetime
    steps: list[AdminStep]
    media: list[AdminMedia]


class AdminActivityUpdate(CamelModel):
    title: str | None = Field(None, min_length=1, max_length=300)
    summary: str | None = None
    content: str | None = None
    group_id: int | None = None
    status: Status | None = None
    age_from_months: int | None = Field(None, ge=0, le=72)
    age_to_months: int | None = Field(None, ge=0, le=72)
    duration_minutes: int | None = Field(None, ge=1, le=240)
    materials: str | None = None
    material_items: list[str] | None = None
    goal: str | None = None
    safety_note: str | None = None
    needs_adult: bool | None = None
    lyrics: str | None = None
    thumbnail_url: str | None = None


class AdminActivityCreate(CamelModel):
    title: str = Field(min_length=1, max_length=300)
    group_id: int
    age_from_months: int = Field(ge=0, le=72)
    age_to_months: int = Field(ge=0, le=72)

    @model_validator(mode="after")
    def age_order(self):
        if self.age_from_months > self.age_to_months:
            raise ValueError("age_from_months phải ≤ age_to_months")
        return self


class AdminStepIn(CamelModel):
    title: str | None = Field(None, max_length=200)
    instruction: str = Field(min_length=1)
    image_url: str | None = None


class AdminStepsUpdate(CamelModel):
    steps: list[AdminStepIn] = Field(max_length=30)


class AdminMediaUpdate(CamelModel):
    caption: str | None = Field(None, max_length=300)
    sort_order: int | None = Field(None, ge=0, le=1000)
