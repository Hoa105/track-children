from datetime import date
from decimal import Decimal
import re
from typing import Annotated, Literal
from pydantic import BaseModel, ConfigDict, Field, BeforeValidator, model_validator


def json_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float, Decimal)):
        raise ValueError('Expected a JSON number')
    return value


Weight = Annotated[Decimal, BeforeValidator(json_number), Field(gt=0, le=200, multiple_of=Decimal('.01'), allow_inf_nan=False)]
Length = Annotated[Decimal, BeforeValidator(json_number), Field(gt=0, le=250, multiple_of=Decimal('.01'), allow_inf_nan=False)]
Head = Annotated[Decimal, BeforeValidator(json_number), Field(gt=0, le=100, multiple_of=Decimal('.01'), allow_inf_nan=False)]


def calendar_date(value):
    if not isinstance(value, (str, date)) or (isinstance(value,str) and not re.fullmatch(r'\d{4}-\d{2}-\d{2}',value)):
        raise ValueError('Expected a calendar date YYYY-MM-DD without a time')
    return value


CalendarDate = Annotated[date, BeforeValidator(calendar_date)]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra='forbid')


class Height(StrictModel):
    value: Length
    measurePosition: Literal['lying', 'standing']


class SaveDay(StrictModel):
    weightKg: Weight | None = None
    height: Height | None = None
    headCircumferenceCm: Head | None = None
    note: str | None = Field(default=None, max_length=2000)

    @model_validator(mode='after')
    def measurements_required(self):
        names = self.model_fields_set & {'weightKg', 'height', 'headCircumferenceCm'}
        if not names or any(getattr(self, n) is None for n in names):
            raise ValueError('Supply at least one non-null measurement; omit unchanged fields')
        return self


class ChildInput(StrictModel):
    fullName: str = Field(min_length=1, max_length=150)
    dateOfBirth: CalendarDate
    gender: Literal['male', 'female']
    gestationalWeeks: int | None = Field(default=None, ge=22, le=45)
    birthWeightKg: Weight | None = None

    @model_validator(mode='after')
    def name_not_blank(self):
        self.fullName = self.fullName.strip()
        if not self.fullName:
            raise ValueError('Name is required')
        return self
