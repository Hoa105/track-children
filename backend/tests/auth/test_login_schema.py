import pytest
from pydantic import ValidationError
from app.features.auth.schemas import Login

DEVICE = {"deviceId": "test", "platform": "web"}

@pytest.mark.parametrize("phone", ["0912345678", "+84912345678", "(091) 234-5678"])
def test_phone_login_normalizes_identifier(phone):
    data = Login(phone=phone, password="secret", device=DEVICE)
    assert data.phone == "+84912345678"
    assert data.identifier == "+84912345678"

@pytest.mark.parametrize("fields", [{}, {"phone": "abc"}, {"email": "invalid"},
    {"email": "parent@example.com", "phone": "0912345678"}])
def test_login_rejects_invalid_or_ambiguous_identifier(fields):
    with pytest.raises(ValidationError):
        Login(**fields, password="secret", device=DEVICE)

def test_existing_email_login_is_supported():
    data = Login(email=" parent@example.com ", password="secret", device=DEVICE)
    assert data.identifier == "parent@example.com"
