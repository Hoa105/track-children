import unicodedata

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class AdminLogin(BaseModel):
    model_config = ConfigDict(extra='forbid')
    email: EmailStr = Field(max_length=254)
    password: str = Field(min_length=1, max_length=1024)

    @field_validator('email', mode='before')
    @classmethod
    def normalize_email(cls, value):
        return value.strip().lower() if isinstance(value, str) else value


class AdminPasswordChange(BaseModel):
    model_config = ConfigDict(extra='forbid')
    currentPassword: str = Field(min_length=1, max_length=1024)
    newPassword: str = Field(min_length=10, max_length=128)


class AdminProfileUpdate(BaseModel):
    model_config = ConfigDict(extra='forbid')
    fullName: str = Field(min_length=2, max_length=150)

    @field_validator('fullName', mode='before')
    @classmethod
    def normalize_name(cls, value):
        if not isinstance(value, str):
            return value
        if any(unicodedata.category(char).startswith('C') for char in value):
            raise ValueError('Full name must not contain control characters')
        return ' '.join(value.split())
