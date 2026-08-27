"""Tests unitaires du GuideService — soumission de vérification d'identité."""

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.exceptions import BadRequestError, ForbiddenError, NotFoundError
from app.services import guide_service as guide_service_module
from app.services.guide_service import GuideService

pytestmark = pytest.mark.unit


def _service():
    svc = GuideService(db=MagicMock())
    svc.guides = MagicMock()
    return svc


def _file(name="photo.jpg"):
    return SimpleNamespace(filename=name, file=object())


def _files():
    return dict(
        cine_number="AB123456",
        license_number="LIC-987",
        profile_photo=_file("profile.jpg"),
        license_photo=_file("license.png"),
        cine_photo=_file("cine.webp"),
    )


def test_submit_verification_rejects_non_guide():
    svc = _service()
    user = SimpleNamespace(id="u1", role="tourist")
    with pytest.raises(ForbiddenError) as exc:
        svc.submit_verification(user, **_files())
    assert exc.value.error_code == "NOT_A_GUIDE"


def test_submit_verification_missing_profile_raises():
    svc = _service()
    svc.guides.get_by_user_id.return_value = None
    user = SimpleNamespace(id="u1", role="guide")
    with pytest.raises(NotFoundError) as exc:
        svc.submit_verification(user, **_files())
    assert exc.value.error_code == "GUIDE_PROFILE_NOT_FOUND"


def test_submit_verification_already_verified_raises():
    svc = _service()
    svc.guides.get_by_user_id.return_value = SimpleNamespace(is_verified=True)
    user = SimpleNamespace(id="u1", role="guide")
    with pytest.raises(BadRequestError) as exc:
        svc.submit_verification(user, **_files())
    assert exc.value.error_code == "ALREADY_VERIFIED"


def test_submit_verification_bad_extension_raises(monkeypatch):
    svc = _service()
    svc.guides.get_by_user_id.return_value = SimpleNamespace(is_verified=False)
    user = SimpleNamespace(id="u1", role="guide")
    files = _files()
    files["profile_photo"] = _file("virus.exe")
    with pytest.raises(BadRequestError) as exc:
        svc.submit_verification(user, **files)
    assert exc.value.error_code == "INVALID_FILE_FORMAT"


def test_submit_verification_success_marks_docs_submitted(monkeypatch):
    svc = _service()
    guide = SimpleNamespace(
        id="g1", is_verified=False, cine_number=None, license_number=None,
        profile_photo_url=None, license_card_url=None, cine_card_url=None,
        has_official_license=False, approval_status="pending",
    )
    svc.guides.get_by_user_id.return_value = guide
    monkeypatch.setattr(
        guide_service_module, "save_upload_file",
        lambda f, dest: f"uploads/x/{f.filename}",
    )
    user = SimpleNamespace(id="u1", role="guide")

    result = svc.submit_verification(user, **_files())

    # RG14 : le statut reste `pending`, la soumission des docs est tracée par le drapeau.
    assert guide.approval_status == "pending"
    assert guide.has_official_license is True
    assert result["approval_status"] == "pending"
    assert result["cine_number"] == "AB123456"
