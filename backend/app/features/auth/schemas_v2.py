from typing import Literal
from uuid import UUID
from pydantic import Field, StrictBool, field_validator, model_validator
from app.features.auth.schemas import Input, Device
from app.features.auth import validation as v

Role = Literal['mother', 'father', 'grandfather', 'grandmother', 'other_guardian']

class Start(Input):
    phone: str
    device: Device
    _phone = field_validator('phone')(v.phone)

class Ticket(Input):
    transactionId: UUID
    transactionToken: str = Field(min_length=32, max_length=256)

class Verify(Ticket):
    code: str = Field(min_length=6, max_length=6, pattern=r'^[0-9]{6}$')

class Profile(Input):
    displayName: str
    defaultRelationship: Role
    acceptedTerms: StrictBool
    documentsDigest: str = Field(min_length=64, max_length=64, pattern=r'^[0-9a-f]{64}$')
    _name = field_validator('displayName')(v.name)

class Complete(Ticket, Profile):
    password: str
    confirmPassword: str
    device: Device
    rememberMe: StrictBool = True
    _password = field_validator('password')(v.password)

    @model_validator(mode='after')
    def confirmation(self):
        if self.password != self.confirmPassword:
            raise ValueError('Passwords do not match')
        return self

class SocialStart(Input):
    provider: Literal['google', 'apple']
    idToken: str = Field(min_length=1, max_length=16000)
    authorizationCode: str | None = Field(default=None, max_length=4096)
    challenge: str | None = Field(default=None, max_length=2048)
    displayName: str = Field(default='', max_length=150)
    device: Device
    rememberMe: StrictBool = True

class SocialComplete(Ticket, Profile):
    device: Device
    rememberMe: StrictBool = True

class PasswordPair(Input):
    newPassword: str
    confirmPassword: str
    _new = field_validator('newPassword')(v.password)
    @model_validator(mode='after')
    def confirmation(self):
        if self.newPassword != self.confirmPassword:
            raise ValueError('Passwords do not match')
        return self

class ChangePassword(PasswordPair):
    currentPassword: str = Field(min_length=1, max_length=128)
    device: Device

class RecoveryStart(Input):
    identifier: str
    device: Device
    @field_validator('identifier')
    @classmethod
    def identifier_format(cls, value):
        return v.email(value) if '@' in value else v.phone(value)

class RecoveryVerify(Verify):
    device: Device

class RecoveryResend(Ticket):
    device: Device

class RecoveryComplete(Ticket, PasswordPair):
    pass

class RecoveryEmail(Ticket):
    pass

class RecoveryProvider(Ticket, SocialStart):
    pass

class Reauth(Input):
    action: Literal['change_email', 'change_phone', 'set_password', 'delete_account', 'link_google', 'link_apple', 'unlink_google', 'unlink_apple']
    target: str | None = None
    currentPassword: str | None = Field(default=None, max_length=128)
    providerCredential: SocialStart | None = None
    @model_validator(mode='after')
    def normalize(self):
        if self.action == 'change_email':
            self.target = v.email(self.target or '')
        elif self.action == 'change_phone':
            self.target = v.phone(self.target or '')
        elif self.target is not None:
            raise ValueError('Unexpected target')
        if (self.currentPassword is None) == (self.providerCredential is None):
            raise ValueError('Provide exactly one reauthentication method')
        return self

class SetupPassword(Ticket, PasswordPair):
    device: Device

class IdentifierVerify(Verify):
    pass

class ProviderLink(Ticket):
    credential: SocialStart

class ProviderUnlink(Ticket):
    provider: Literal['google','apple']
    credential: SocialStart | None = None

class DeleteAccount(Ticket):
    appleCredential: SocialStart | None = None

class AppleEvent(Input):
    payload: str = Field(min_length=1,max_length=20000)
