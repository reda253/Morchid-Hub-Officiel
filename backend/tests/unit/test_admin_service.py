"""Tests unitaires du AdminService — approbation guides, support, garde-fous."""

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.exceptions import BadRequestError, NotFoundError
from app.services.admin_service import AdminService

pytestmark = pytest.mark.unit


def _service():
    svc = AdminService(db=MagicMock())
    svc.users = MagicMock()
    svc.guides = MagicMock()
    svc.support = MagicMock()
    return svc


# ── Utilisateurs ───────────────────────────────────────────────────────────
def test_toggle_user_status_self_blocked():
    svc = _service()
    admin = SimpleNamespace(id="a1")
    svc.users.get_by_id.return_value = SimpleNamespace(id="a1", is_active=True)
    with pytest.raises(BadRequestError) as exc:
        svc.toggle_user_status("a1", admin)
    assert exc.value.error_code == "SELF_DEACTIVATION"


def test_toggle_user_status_unknown_raises():
    svc = _service()
    svc.users.get_by_id.return_value = None
    with pytest.raises(NotFoundError) as exc:
        svc.toggle_user_status("xx", SimpleNamespace(id="a1"))
    assert exc.value.error_code == "USER_NOT_FOUND"


def test_toggle_user_status_flips_active():
    svc = _service()
    user = SimpleNamespace(id="u2", is_active=True)
    svc.users.get_by_id.return_value = user
    result = svc.toggle_user_status("u2", SimpleNamespace(id="a1"))
    assert result.is_active is False


# ── Approbation guides ─────────────────────────────────────────────────────
def test_approve_non_pending_guide_raises_invalid_status():
    svc = _service()
    svc.guides.get_by_id.return_value = SimpleNamespace(
        id="g1", approval_status="approved"
    )
    with pytest.raises(BadRequestError) as exc:
        svc.approve_guide("g1")
    assert exc.value.error_code == "INVALID_STATUS"


def test_approve_guide_sets_approved_and_verified():
    svc = _service()
    guide = SimpleNamespace(
        id="g1", approval_status="pending", has_official_license=True,
        is_verified=False, rejection_reason="old",
    )
    svc.guides.get_by_id.return_value = guide
    result = svc.approve_guide("g1")
    assert result.approval_status == "approved"
    assert result.is_verified is True
    assert result.rejection_reason is None


def test_approve_guide_without_documents_raises():
    """RG15 : impossible d'approuver un guide qui n'a pas soumis ses documents."""
    svc = _service()
    svc.guides.get_by_id.return_value = SimpleNamespace(
        id="g1", approval_status="pending", has_official_license=False,
    )
    with pytest.raises(BadRequestError) as exc:
        svc.approve_guide("g1")
    assert exc.value.error_code == "NO_DOCUMENTS"


def test_reject_guide_sets_rejected_with_reason():
    svc = _service()
    guide = SimpleNamespace(
        id="g1", approval_status="pending",
        is_verified=True, rejection_reason=None,
    )
    svc.guides.get_by_id.return_value = guide
    result = svc.reject_guide("g1", "Documents illisibles, merci de renvoyer.")
    assert result.approval_status == "rejected"
    assert result.is_verified is False
    assert result.rejection_reason == "Documents illisibles, merci de renvoyer."


def test_approve_unknown_guide_raises_not_found():
    svc = _service()
    svc.guides.get_by_id.return_value = None
    with pytest.raises(NotFoundError) as exc:
        svc.approve_guide("gX")
    assert exc.value.error_code == "GUIDE_NOT_FOUND"


# ── Support ────────────────────────────────────────────────────────────────
def test_resolve_already_resolved_raises():
    svc = _service()
    svc.support.get_by_id.return_value = SimpleNamespace(id="m1", is_resolved=True)
    with pytest.raises(BadRequestError) as exc:
        svc.resolve_support_message("m1")
    assert exc.value.error_code == "ALREADY_RESOLVED"


def test_resolve_unknown_message_raises():
    svc = _service()
    svc.support.get_by_id.return_value = None
    with pytest.raises(NotFoundError) as exc:
        svc.resolve_support_message("mX")
    assert exc.value.error_code == "MESSAGE_NOT_FOUND"


# ── Statistiques ───────────────────────────────────────────────────────────
def test_get_stats_aggregates_counts():
    svc = _service()
    svc.users.count.return_value = 10
    svc.users.count_active.return_value = 7
    svc.guides.count.return_value = 4
    svc.guides.count_by_status.side_effect = lambda s: {
        "pending": 1, "approved": 2, "rejected": 1
    }[s]
    svc.support.count_unresolved.return_value = 3

    stats = svc.get_stats()

    assert stats["users"] == {"total": 10, "active": 7, "inactive": 3}
    assert stats["guides"]["approved"] == 2
    assert stats["support"]["unresolved"] == 3
