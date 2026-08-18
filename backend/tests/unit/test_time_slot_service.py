"""Tests unitaires du TimeSlotService — RG21 (non-chevauchement), propriété, annulation."""

from datetime import datetime
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.models import TimeSlot
from app.services.time_slot_service import TimeSlotService

pytestmark = pytest.mark.unit


def _service():
    svc = TimeSlotService(db=MagicMock())
    svc.guides = MagicMock()
    svc.routes = MagicMock()
    svc.slots = MagicMock()
    return svc


def _dt(day, hour):
    return datetime(2026, 9, day, hour, 0, 0)


def _existing_slot(day, h1, h2, status="upcoming"):
    return TimeSlot(
        route_id="r1", scheduled_start=_dt(day, h1),
        scheduled_end=_dt(day, h2), status=status,
    )


def test_create_slot_rejects_non_guide():
    svc = _service()
    user = SimpleNamespace(id="u1", role="tourist")
    with pytest.raises(ForbiddenError) as exc:
        svc.create_slot(user, "r1", _dt(1, 9), _dt(1, 11))
    assert exc.value.error_code == "NOT_A_GUIDE"


def test_create_slot_route_not_owned_raises():
    svc = _service()
    svc.guides.get_by_user_id.return_value = SimpleNamespace(id="g1")
    svc.routes.get_by_id_and_guide.return_value = None
    user = SimpleNamespace(id="u1", role="guide")
    with pytest.raises(NotFoundError) as exc:
        svc.create_slot(user, "r1", _dt(1, 9), _dt(1, 11))
    assert exc.value.error_code == "ROUTE_NOT_FOUND"


def test_create_slot_overlap_rejected_rg21():
    svc = _service()
    svc.guides.get_by_user_id.return_value = SimpleNamespace(id="g1")
    svc.routes.get_by_id_and_guide.return_value = SimpleNamespace(id="r1")
    # Créneau existant 10h–12h ; nouveau 11h–13h chevauche.
    svc.slots.list_active_for_guide.return_value = [_existing_slot(1, 10, 12)]
    user = SimpleNamespace(id="u1", role="guide")
    with pytest.raises(ConflictError) as exc:
        svc.create_slot(user, "r1", _dt(1, 11), _dt(1, 13))
    assert exc.value.error_code == "SLOT_CONFLICT"


def test_create_slot_adjacent_ok():
    svc = _service()
    svc.guides.get_by_user_id.return_value = SimpleNamespace(id="g1")
    svc.routes.get_by_id_and_guide.return_value = SimpleNamespace(id="r1")
    # Existant 10h–12h ; nouveau 12h–14h est adjacent, PAS de chevauchement.
    svc.slots.list_active_for_guide.return_value = [_existing_slot(1, 10, 12)]
    user = SimpleNamespace(id="u1", role="guide")

    slot = svc.create_slot(user, "r1", _dt(1, 12), _dt(1, 14))

    svc.slots.add.assert_called_once()
    assert slot.status == "upcoming"


def test_create_slot_ignores_cancelled_conflict():
    svc = _service()
    svc.guides.get_by_user_id.return_value = SimpleNamespace(id="g1")
    svc.routes.get_by_id_and_guide.return_value = SimpleNamespace(id="r1")
    # Un créneau annulé ne bloque pas, même s'il chevauche.
    svc.slots.list_active_for_guide.return_value = [
        _existing_slot(1, 10, 12, status="cancelled")
    ]
    user = SimpleNamespace(id="u1", role="guide")

    svc.create_slot(user, "r1", _dt(1, 11), _dt(1, 13))
    svc.slots.add.assert_called_once()


def test_cancel_slot_already_cancelled_raises():
    svc = _service()
    svc.slots.get_by_id.return_value = TimeSlot(
        route_id="r1", scheduled_start=_dt(1, 9), scheduled_end=_dt(1, 11),
        status="cancelled",
    )
    svc.guides.get_by_user_id.return_value = SimpleNamespace(id="g1")
    svc.routes.get_by_id_and_guide.return_value = SimpleNamespace(id="r1")
    user = SimpleNamespace(id="u1", role="guide")
    with pytest.raises(ConflictError) as exc:
        svc.cancel_slot(user, "s1")
    assert exc.value.error_code == "ALREADY_CANCELLED"
