"""Request / response bodies. Field names are camelCase to match the mobile and admin clients."""

import datetime as dt

from pydantic import BaseModel, ConfigDict, Field, model_validator
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


# ---------------------------------------------------------------------
# Mobile: lịch tiêm & sổ tiêm của bé
# ---------------------------------------------------------------------
class ScheduleProduct(CamelModel):
    code: str
    name: str
    origin: str | None
    dose_count: int | None  # NULL = theo lịch của vắc xin


class ScheduleVaccine(CamelModel):
    code: str
    name: str
    prevents: str
    is_tcmr: bool
    description: str | None
    # Phác đồ thay thế: mỗi bé theo 1 option trong cùng choice_group
    choice_group: str | None
    choice_option: str | None
    choice_label: str | None
    choice_default: bool
    products: list[ScheduleProduct]


class ScheduleDose(CamelModel):
    """Một mũi trong lịch — mobile tính ngày dự kiến từ các trường này."""

    id: str  # vaccine_schedules.code
    vaccine: str  # vaccines.code
    dose_number: int
    dose_label: str
    age_weeks: int | None  # có giá trị thì thay age_months + offset_days
    age_months: int
    offset_days: int
    after_dose: str | None  # mã mũi trước: ngày dự kiến >= mũi trước + min_interval_days
    min_interval_days: int | None
    repeat_every_months: int | None  # mũi nhắc lặp lại; lần thứ n có id "<id>@n"
    repeat_until_months: int | None
    is_tcmr: bool
    note: str | None


class Schedule(CamelModel):
    vaccines: list[ScheduleVaccine]
    doses: list[ScheduleDose]


class VaccinationRecord(CamelModel):
    """Một mũi trong sổ tiêm của bé — cùng dạng bản ghi DemoStore.vaccinations của mobile.

    - custom = false: mũi theo lịch, `id` là mã mũi trong lịch (vd `5in1-1`),
      mũi lặp lại thêm `@lần` (vd `flu-yearly@2`)
    - custom = true: mũi phụ huynh tự thêm, `id` do mobile sinh (vd `custom-…`)
    - given = false: chưa tiêm, `date` là ngày hẹn
    - given = true: `date` là ngày tiêm thực tế; `scheduled_date` là ngày hẹn — mobile gửi
      ngày hẹn bố mẹ đã đặt, hoặc ngày dự kiến lúc ghi nhận nếu chưa từng đặt hẹn.
      Bỏ trống thì giữ ngày hẹn đã lưu.
    """

    id: str = Field(min_length=1, max_length=80)
    custom: bool = False
    group_id: str | None = Field(default=None, max_length=80)
    name: str | None = Field(default=None, max_length=150)
    prevents: str | None = Field(default=None, max_length=200)
    dose_label: str | None = Field(default=None, max_length=50)
    product: str | None = Field(default=None, max_length=40)  # vaccine_products.code
    given: bool
    date: dt.date
    scheduled_date: dt.date | None = None
    place: str = Field(default="", max_length=200)
    appointment_place: str | None = Field(default=None, max_length=200)
    reaction: str = ""
    note: str = ""

    @model_validator(mode="after")
    def _custom_needs_name(self) -> "VaccinationRecord":
        if self.custom and not (self.name or "").strip():
            raise ValueError("Mũi tự thêm cần tên vắc xin")
        return self


class VaccinationBatch(CamelModel):
    records: list[VaccinationRecord] = Field(min_length=1, max_length=50)


class VaccinePlans(CamelModel):
    """{mã vắc xin: true = theo dõi, false = không tiêm, null = về mặc định}."""

    plans: dict[str, bool | None] = Field(min_length=1, max_length=100)


# ---------------------------------------------------------------------
# Web admin: danh mục vắc xin & lịch tiêm
# ---------------------------------------------------------------------
_CODE = r"^[a-z0-9-]{2,40}$"


_CHOICE = r"^[a-z0-9-]{2,30}$"


class AdminVaccine(CamelModel):
    id: int
    code: str
    name: str
    disease: str | None
    is_mandatory: bool
    description: str | None
    is_active: bool
    choice_group: str | None
    choice_option: str | None
    choice_label: str | None
    choice_default: bool
    sort_order: int
    schedule_count: int


class AdminVaccineUpdate(CamelModel):
    name: str | None = Field(default=None, min_length=1, max_length=150)
    disease: str | None = Field(default=None, max_length=200)
    is_mandatory: bool | None = None
    description: str | None = None
    is_active: bool | None = None
    choice_group: str | None = Field(default=None, pattern=_CHOICE)
    choice_option: str | None = Field(default=None, pattern=_CHOICE)
    choice_label: str | None = Field(default=None, max_length=100)
    choice_default: bool | None = None
    sort_order: int | None = Field(default=None, ge=0, le=1000)


class AdminVaccineCreate(CamelModel):
    code: str = Field(pattern=r"^[a-z0-9-]{2,30}$")
    name: str = Field(min_length=1, max_length=150)
    disease: str | None = Field(default=None, max_length=200)
    is_mandatory: bool = False
    description: str | None = None
    is_active: bool = True
    choice_group: str | None = Field(default=None, pattern=_CHOICE)
    choice_option: str | None = Field(default=None, pattern=_CHOICE)
    choice_label: str | None = Field(default=None, max_length=100)
    choice_default: bool = False
    sort_order: int = Field(default=100, ge=0, le=1000)


class AdminProduct(CamelModel):
    id: int
    vaccine_id: int
    vaccine_name: str
    code: str
    name: str
    origin: str | None
    dose_count: int | None
    note: str | None
    is_active: bool
    record_count: int


class AdminProductCreate(CamelModel):
    vaccine_id: int
    code: str = Field(pattern=_CODE)
    name: str = Field(min_length=1, max_length=100)
    origin: str | None = Field(default=None, max_length=60)
    dose_count: int | None = Field(default=None, ge=1, le=20)
    note: str | None = None
    is_active: bool = True


class AdminProductUpdate(CamelModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    origin: str | None = Field(default=None, max_length=60)
    dose_count: int | None = Field(default=None, ge=1, le=20)
    note: str | None = None
    is_active: bool | None = None


class AdminSchedule(CamelModel):
    id: int
    vaccine_id: int
    vaccine_name: str
    code: str | None
    dose_number: int
    dose_label: str | None
    age_weeks: int | None
    age_months: int
    offset_days: int
    age_to_days: int | None
    after_schedule_id: int | None
    after_code: str | None
    min_interval_days: int | None
    repeat_every_months: int | None
    repeat_until_months: int | None
    is_mandatory: bool | None
    is_tcmr: bool
    note: str | None
    is_active: bool
    record_count: int


class AdminScheduleUpdate(CamelModel):
    code: str | None = Field(default=None, pattern=_CODE)
    dose_number: int | None = Field(default=None, ge=1, le=20)
    dose_label: str | None = Field(default=None, max_length=50)
    age_weeks: int | None = Field(default=None, ge=0, le=52)
    age_months: int | None = Field(default=None, ge=0, le=216)
    offset_days: int | None = Field(default=None, ge=0, le=365)
    age_to_days: int | None = Field(default=None, ge=0)
    after_schedule_id: int | None = None
    min_interval_days: int | None = Field(default=None, ge=0)
    repeat_every_months: int | None = Field(default=None, ge=1, le=120)
    repeat_until_months: int | None = Field(default=None, ge=1, le=216)
    is_mandatory: bool | None = None
    note: str | None = None
    is_active: bool | None = None


class AdminScheduleCreate(AdminScheduleUpdate):
    vaccine_id: int
    code: str = Field(pattern=_CODE)
    dose_number: int = Field(ge=1, le=20)
    age_months: int = Field(default=0, ge=0, le=216)
    offset_days: int = Field(default=0, ge=0, le=365)
    is_active: bool = True

    @model_validator(mode="after")
    def _age_weeks_sets_months(self) -> "AdminScheduleCreate":
        if self.age_weeks is not None:
            self.age_months, self.offset_days = divmod(self.age_weeks * 7, 30)
        return self


class CustomDoseSummary(CamelModel):
    """Một loại vắc xin phụ huynh tự thêm, gộp theo tên (không định danh bé / phụ huynh)."""

    key: str  # tên đã chuẩn hóa (chữ thường, gộp khoảng trắng)
    name: str  # cách viết phổ biến nhất
    prevents: str | None  # bệnh phòng ngừa phổ biến nhất
    child_count: int
    dose_count: int
    given_count: int
    planned_count: int
    first_recorded_at: dt.datetime
    last_recorded_at: dt.datetime
    catalog_vaccine: str | None  # mã vắc xin trùng tên trong danh mục / sản phẩm, nếu có


class CustomDoseReport(CamelModel):
    items: list[CustomDoseSummary]
    total_children: int  # số bé có ít nhất 1 mũi tự thêm
    total_doses: int
