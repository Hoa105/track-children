import re
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, StrictBool, field_validator, model_validator


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=False)


class Device(Input):
    deviceId: str | None = Field(default=None, min_length=1, max_length=100)
    deviceName: str | None = Field(default=None, max_length=100)
    platform: Literal["android", "ios", "web"]


class Register(Input):
    displayName: str = Field(default="Phụ huynh", max_length=150)
    email: EmailStr | None = Field(default=None, max_length=254)
    phone: str | None = None
    password: str = Field(min_length=8, max_length=64)
    defaultRelationship: Literal["mother", "father", "grandfather", "grandmother", "other_guardian"] = "mother"
    acceptedTerms: StrictBool

    @field_validator("displayName", "email", mode="before")
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("displayName")
    @classmethod
    def default_display_name(cls, value):
        return value or "Phụ huynh"

    @field_validator("phone")
    @classmethod
    def phone_format(cls, value):
        if value is None:
            return None
        value = re.sub(r"[\s()-]", "", value)
        if value.startswith("0"):
            value = "+84" + value[1:]
        if not re.fullmatch(r"\+[1-9][0-9]{7,14}", value):
            raise ValueError("Invalid E.164 phone number")
        return value

    @model_validator(mode="after")
    def require_identifier(self):
        if (self.email is None) == (self.phone is None):
            raise ValueError("Provide exactly one of email or phone")
        return self


class Challenge(Input):
    verificationId: UUID
    registrationToken: str = Field(min_length=1, max_length=512)


class Verify(Challenge):
    code: str = Field(pattern=r"^[0-9]{6}$")
    rememberMe: StrictBool = True
    device: Device


class Login(Input):
    email: EmailStr | None = Field(default=None, max_length=254)
    phone: str | None = None
    password: str = Field(min_length=1, max_length=128)
    rememberMe: StrictBool = True
    device: Device

    @field_validator("email", mode="before")
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("phone")
    @classmethod
    def phone_format(cls, value):
        return Register.phone_format(value) if value is not None else None

    @model_validator(mode="after")
    def require_identifier(self):
        if (self.email is None) == (self.phone is None):
            raise ValueError("Provide exactly one of email or phone")
        return self

    @property
    def identifier(self):
        return str(self.email).lower() if self.email is not None else self.phone


class Refresh(Input):
    refreshToken: str = Field(min_length=1, max_length=512)


class SocialRegister(Input):
    provider: Literal['google', 'apple']
    idToken: str = Field(min_length=1, max_length=16000)
    authorizationCode: str | None = Field(default=None, max_length=4096)
    challenge: str | None = Field(default=None, max_length=2048)
    displayName: str = Field(default='Phụ huynh', max_length=150)
    defaultRelationship: Literal['mother','father','grandfather','grandmother','other_guardian'] = 'mother'
    acceptedTerms: StrictBool
    rememberMe: StrictBool = True
    device: Device
