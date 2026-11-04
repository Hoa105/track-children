from typing import Literal

from pydantic import BaseModel, Field, model_validator

AccessLevel = Literal["none", "view", "edit"]
PermissionScope = Literal[
    "growth", "assessment", "vaccination", "teething", "diary", "activities"
]


class PermissionUpdate(BaseModel):
    permissions: dict[PermissionScope, AccessLevel]


class InvitationCreate(BaseModel):
    email: str | None = Field(default=None, max_length=320)
    phone: str | None = Field(default=None, max_length=16)
    relationship: str | None = Field(default=None, max_length=30)
    permissions: dict[PermissionScope, AccessLevel]

    @model_validator(mode="after")
    def one_contact(self):
        if (self.email is None) == (self.phone is None):
            raise ValueError("Provide exactly one of email or phone")
        if self.email is not None:
            self.email = self.email.strip().lower()
        if self.phone is not None:
            phone = "".join(ch for ch in self.phone if ch.isdigit() or ch == "+")
            self.phone = "+84" + phone[1:] if phone.startswith("0") else phone
        return self

