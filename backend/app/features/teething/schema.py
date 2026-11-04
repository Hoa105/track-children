"""Wire models for the mobile teething tracker."""

import datetime as dt

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class ToothRecord(CamelModel):
    tooth_code: str = Field(pattern=r"^[5-8][1-5]$")
    erupted_on: dt.date


class ToothRecords(CamelModel):
    records: list[ToothRecord]


class ToothUpsert(CamelModel):
    erupted_on: dt.date
    timezone_offset_minutes: int = Field(ge=-720, le=840)
