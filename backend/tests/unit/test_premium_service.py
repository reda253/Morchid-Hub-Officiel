"""Tests unitaires du PremiumService — activation 30j, no-op si déjà actif."""

from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.exceptions import ForbiddenError, NotFoundError
from app.services.premium_service import PREMIUM_DURATION_DAYS, PremiumService

pytestmark = pytest.mark.unit


def _service():
    svc = PremiumService(db=MagicMock())
    svc.guides = MagicMock()
    svc.subscriptions = MagicMock()
    return svc


def test_upgrade_rejects_non_guide():
    svc = _service()
    user = SimpleNamespace(id="u1", role="tourist")
    with pytest.raises(ForbiddenError) as exc:
        svc.upgrade(user)
    assert exc.value.error_code == "NOT_A_GUIDE"


def test_upgrade_missing_profile_raises():
    svc = _service()
    svc.guides.get_by_user_id.return_value = None
    user = SimpleNamespace(id="u1", role="guide")
    with pytest.raises(NotFoundError) as exc:
        svc.upgrade(user)
    assert exc.value.error_code == "GUIDE_PROFILE_NOT_FOUND"


def test_upgrade_fresh_activates_30_days_and_records_subscription():
    svc = _service()
    guide = SimpleNamespace(id="g1", is_premium=False, premium_until=None)
    svc.guides.get_by_user_id.return_value = guide
    user = SimpleNamespace(id="u1", role="guide")

    message, data = svc.upgrade(user)

    assert guide.is_premium is True
    assert guide.premium_until is not None
    assert data["days_remaining"] == PREMIUM_DURATION_DAYS
    assert "Premium" in message
    # Un enregistrement d'abonnement facturable est créé (base des analytics).
    svc.subscriptions.add.assert_called_once()


def test_upgrade_already_active_is_noop():
    svc = _service()
    future = datetime.now() + timedelta(days=10)
    guide = SimpleNamespace(is_premium=True, premium_until=future)
    svc.guides.get_by_user_id.return_value = guide
    user = SimpleNamespace(id="u1", role="guide")

    message, data = svc.upgrade(user)

    assert data["is_premium"] is True
    assert "déjà" in message.lower()
    # Pas de commit : aucune réécriture de premium_until.
    svc.db.commit.assert_not_called()
