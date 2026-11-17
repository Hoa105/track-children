"""Request / response bodies. Field names are camelCase to match the mobile client."""

import datetime as dt
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

DomainCode = Literal["gross_motor", "fine_motor", "language", "cognitive", "social_emotional"]
MediaType = Literal["image", "video"]


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class MediaRef(CamelModel):
    """Ảnh / video gắn với nhật ký; id do mobile sinh, file gửi riêng (PUT .../media/{id})."""

    id: UUID
    type: MediaType


class DiaryEntryIn(CamelModel):
    """Một nhật ký; id do mobile sinh nằm trên đường dẫn."""

    # Giờ máy phụ huynh, không múi giờ (mobile gửi DateTime.toIso8601String())
    date: dt.datetime
    note: str = Field(max_length=5000)
    mood: str | None = Field(None, max_length=20)
    domains: list[DomainCode] = Field(default_factory=list, max_length=5)
    # Thứ tự hiển thị; file đã tải lên mà không còn trong danh sách sẽ bị xóa
    media: list[MediaRef] = Field(default_factory=list, max_length=10)
    activity_id: str | None = Field(None, max_length=80)
    activity_name: str | None = Field(None, max_length=200)
    # Bản sao nhận xét AI mobile đang hiển thị (VideoInsight.toJson)
    insight: dict[str, Any] | None = None


class DiaryMedia(MediaRef):
    """File đã lưu trên MinIO; url là link tải có thời hạn."""

    url: str
    expires_at: dt.datetime
    size_bytes: int | None


class MediaUrl(CamelModel):
    url: str
    expires_at: dt.datetime


class DiaryEntry(DiaryEntryIn):
    id: str
    updated_at: dt.datetime
    # Chỉ file đã tải lên xong
    media: list[DiaryMedia]
