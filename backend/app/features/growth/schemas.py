from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal
from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, model_validator


def number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float, Decimal)):
        raise ValueError("Expected JSON number")
    return value


Value = Annotated[
    Decimal,
    BeforeValidator(number),
    Field(gt=0, le=99999.99, multiple_of=Decimal(".01"), allow_inf_nan=False),
]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Height(Strict):
    value: Value
    measurePosition: Literal["lying", "standing"]


class SaveDay(Strict):
    weightKg: Value | None = None
    height: Height | None = None
    headCircumferenceCm: Value | None = None
    measuredAt: datetime | None = None
    note: str | None = Field(None, max_length=2000)

    @model_validator(mode="after")
    def valid(self):
        names = self.model_fields_set & {"weightKg", "height", "headCircumferenceCm"}
        if not names or any(getattr(self, name) is None for name in names):
            raise ValueError("Supply at least one non-null metric")
        if "measuredAt" in self.model_fields_set and (
            self.measuredAt is None or self.measuredAt.tzinfo is None
        ):
            raise ValueError("measuredAt must include timezone")
        return self
