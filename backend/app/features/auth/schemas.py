import re
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, StrictBool, field_validator


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=False)


class Device(Input):
    deviceId: str = Field(min_length=1, max_length=100)
    deviceName: str | None = Field(default=None, max_length=100)
    platform: Literal["android", "ios", "web"]


class Consent(Input):
    documentId: UUID
    isAccepted: StrictBool


class Register(Input):
    fullName: str = Field(min_length=1, max_length=150)
    username: str = Field(pattern=r"^[a-z0-9_.]{3,30}$")
    email: EmailStr = Field(max_length=254)
    phone: str
    password: str = Field(min_length=6, max_length=128)
    relationship: Literal["mother", "father", "guardian"]
    consents: list[Consent]

    @field_validator("password")
    @classmethod
    def password_complexity(cls, value):
        if not all(
            re.search(pattern, value)
            for pattern in (r"[a-z]", r"[A-Z]", r"[0-9]", r"[^a-zA-Z0-9\s]")
        ):
            raise ValueError(
                "Password must include lowercase, uppercase, digit and special character"
            )
        return value

    @field_validator("fullName", "username", "email", mode="before")
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value

    @field_validator("username", mode="before")
    @classmethod
    def lower(cls, value):
        return value.strip().lower() if isinstance(value, str) else value

    @field_validator("phone")
    @classmethod
    def phone_format(cls, value):
        value = re.sub(r"[\s()-]", "", value)
        if value.startswith("0"):
            value = "+84" + value[1:]
        if not re.fullmatch(r"\+[1-9][0-9]{7,14}", value):
            raise ValueError("Invalid E.164 phone number")
        return value

    @field_validator("consents")
    @classmethod
    def unique_consents(cls, value):
        if len({c.documentId for c in value}) != len(value):
            raise ValueError("Duplicate documentId")
        return value


class Challenge(Input):
    verificationId: UUID
    registrationToken: str = Field(min_length=1, max_length=512)


class Verify(Challenge):
    code: str = Field(pattern=r"^[0-9]{6}$")
    rememberMe: StrictBool = True
    device: Device


class Login(Input):
    email: EmailStr = Field(max_length=254)
    password: str = Field(min_length=1, max_length=128)
    rememberMe: StrictBool = True
    device: Device

    @field_validator("email", mode="before")
    @classmethod
    def trim(cls, value):
        return value.strip() if isinstance(value, str) else value


class Refresh(Input):
    refreshToken: str = Field(min_length=1, max_length=512)
