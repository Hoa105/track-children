"""Wire models for the mobile teething tracker."""

import datetime as dt
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class ToothRecord(CamelModel):
    tooth_code: str = Field(pattern=r"^[5-8][1-5]$")
    erupted_on: dt.date
    version: UUID
    note: str | None = None


class ToothRecords(CamelModel):
    records: list[ToothRecord]


class ToothUpsert(CamelModel):
    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, extra="forbid"
    )

    erupted_on: dt.date
    timezone_offset_minutes: int = Field(ge=-720, le=840, strict=True)
    expected_version: UUID | None
    note: str | None = Field(default=None, max_length=1000)

    @field_validator("note")
    @classmethod
    def normalize_note(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if "\x00" in value:
            raise ValueError("Ghi chú không được chứa ký tự null")
        return value.strip() or None
