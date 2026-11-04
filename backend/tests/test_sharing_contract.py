import pytest
from pydantic import ValidationError

from app.features.sharing.router import router
from app.features.sharing.schema import InvitationCreate, PermissionUpdate


def test_sharing_routes_are_registered():
    routes = {(route.path, frozenset(route.methods)) for route in router.routes}
    assert ("/api/v1/children/{child_id}/sharing", frozenset({"GET"})) in routes
    assert (
        "/api/v1/children/{child_id}/sharing/members/{member_id}",
        frozenset({"PUT"}),
    ) in routes
    assert (
        "/api/v1/children/{child_id}/sharing/invitations", frozenset({"POST"})
    ) in routes


def test_permissions_accept_independent_teething_scope():
    body = PermissionUpdate(
        permissions={"vaccination": "none", "teething": "edit"}
    )
    assert body.permissions["vaccination"] == "none"
    assert body.permissions["teething"] == "edit"


def test_permission_keys_and_levels_are_closed_enums():
    with pytest.raises(ValidationError):
        PermissionUpdate(permissions={"chatbot": "view"})
    with pytest.raises(ValidationError):
        PermissionUpdate(permissions={"teething": "owner"})


def test_invitation_requires_exactly_one_contact():
    permissions = {"teething": "view"}
    assert InvitationCreate(
        email=" Care@example.test ", permissions=permissions
    ).email == "care@example.test"
    assert InvitationCreate(
        phone="0900 000 000", permissions=permissions
    ).phone == "+84900000000"
    with pytest.raises(ValidationError):
        InvitationCreate(permissions=permissions)
    with pytest.raises(ValidationError):
        InvitationCreate(
            email="care@example.test", phone="+84900000000", permissions=permissions
        )
