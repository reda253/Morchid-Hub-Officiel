"""Tests unitaires du AuthService (repositories mockés, aucune BDD).

Vérifie les règles métier d'inscription, connexion, vérification d'email,
renvoi, mot de passe oublié / reset, et calcul de complétion de profil.
"""

from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.auth import decode_access_token, hash_password
from app.exceptions import BadRequestError, UnauthorizedError
from app.schemas import UserRegistration
from app.services.auth_service import AuthService

pytestmark = pytest.mark.unit


def _service():
    """AuthService avec db + repos + notifier mockés."""
    svc = AuthService(db=MagicMock())
    svc.users = MagicMock()
    svc.guides = MagicMock()
    svc.notifier = MagicMock()
    return svc


def _tourist_registration():
    return UserRegistration(
        personal_info={
            "full_name": "Test Tourist",
            "email": "tourist@example.com",
            "phone": "0612345678",
            "date_of_birth": "1990-01-01",
        },
        role="tourist",
        password="Marrakech2026",
    )


def _guide_registration():
    return UserRegistration(
        personal_info={
            "full_name": "Test Guide",
            "email": "guide@example.com",
            "phone": "0612345679",
            "date_of_birth": "1985-01-01",
        },
        role="guide",
        password="Marrakech2026",
        guide_details={
            "languages": ["Français"],
            "specialties": ["culture"],
            "cities_covered": ["Fès"],
            "years_of_experience": 4,
            "bio": "Guide passionné par l'histoire de Fès et son patrimoine unique.",
        },
    )


# ── Inscription ────────────────────────────────────────────────────────────
def test_register_duplicate_email_raises_email_exists():
    svc = _service()
    svc.users.get_by_email.return_value = object()  # email déjà pris
    with pytest.raises(BadRequestError) as exc:
        svc.register(_tourist_registration())
    assert exc.value.error_code == "EMAIL_EXISTS"
    assert exc.value.status_code == 400


def test_register_duplicate_phone_raises_phone_exists():
    svc = _service()
    svc.users.get_by_email.return_value = None
    svc.users.get_by_phone.return_value = object()
    with pytest.raises(BadRequestError) as exc:
        svc.register(_tourist_registration())
    assert exc.value.error_code == "PHONE_EXISTS"


def test_register_tourist_creates_user_and_sends_email():
    svc = _service()
    svc.users.get_by_email.return_value = None
    svc.users.get_by_phone.return_value = None

    user, guide, message = svc.register(_tourist_registration())

    assert guide is None
    assert user.role == "tourist"
    assert user.is_email_verified is False
    assert user.verification_token  # token généré
    svc.users.add.assert_called_once()
    svc.guides.add.assert_not_called()
    svc.notifier.send_verification_email.assert_called_once()
    assert "Bienvenue" in message


def test_register_guide_creates_pending_guide_profile():
    svc = _service()
    svc.users.get_by_email.return_value = None
    svc.users.get_by_phone.return_value = None

    user, guide, message = svc.register(_guide_registration())

    assert user.role == "guide"
    assert guide is not None
    assert guide.approval_status == "pending"
    assert guide.is_verified is False
    svc.guides.add.assert_called_once()


# ── Connexion ──────────────────────────────────────────────────────────────
def test_login_unknown_email_raises_invalid_credentials():
    svc = _service()
    svc.users.get_by_email.return_value = None
    with pytest.raises(UnauthorizedError) as exc:
        svc.login("nobody@example.com", "whatever")
    assert exc.value.error_code == "INVALID_CREDENTIALS"


def test_login_wrong_password_raises_invalid_credentials():
    svc = _service()
    svc.users.get_by_email.return_value = SimpleNamespace(
        password_hash=hash_password("goodpass"), is_active=True
    )
    with pytest.raises(UnauthorizedError) as exc:
        svc.login("user@example.com", "badpass")
    assert exc.value.error_code == "INVALID_CREDENTIALS"


def test_login_disabled_account_raises_account_disabled_403():
    svc = _service()
    svc.users.get_by_email.return_value = SimpleNamespace(
        password_hash=hash_password("goodpass"), is_active=False
    )
    with pytest.raises(BadRequestError) as exc:
        svc.login("user@example.com", "goodpass")
    assert exc.value.error_code == "ACCOUNT_DISABLED"
    assert exc.value.status_code == 403


def test_login_success_returns_decodable_token():
    svc = _service()
    user = SimpleNamespace(
        id="u1", email="user@example.com", role="guide",
        password_hash=hash_password("goodpass"), is_active=True, token_version=0,
    )
    svc.users.get_by_email.return_value = user

    got_user, token = svc.login("user@example.com", "goodpass")

    assert got_user is user
    payload = decode_access_token(token)
    assert payload["sub"] == "u1"
    assert payload["role"] == "guide"


# ── Vérification d'email ───────────────────────────────────────────────────
def test_verify_email_invalid_token_raises():
    svc = _service()
    svc.users.get_by_verification_token.return_value = None
    with pytest.raises(BadRequestError) as exc:
        svc.verify_email("bad")
    assert exc.value.error_code == "INVALID_TOKEN"


def test_verify_email_expired_token_raises():
    svc = _service()
    svc.users.get_by_verification_token.return_value = SimpleNamespace(
        verification_token_expires_at=datetime.utcnow() - timedelta(hours=1),
        is_email_verified=False, verification_token="t",
    )
    with pytest.raises(BadRequestError) as exc:
        svc.verify_email("t")
    # Un token expiré et un token inconnu renvoient volontairement le même code :
    # les distinguer dirait à un appelant anonyme que le token a existé.
    assert exc.value.error_code == "INVALID_TOKEN"


def test_verify_email_success_clears_token():
    svc = _service()
    user = SimpleNamespace(
        verification_token_expires_at=datetime.utcnow() + timedelta(hours=1),
        is_email_verified=False, verification_token="t",
    )
    svc.users.get_by_verification_token.return_value = user
    result = svc.verify_email("t")
    assert result.is_email_verified is True
    assert result.verification_token is None


# ── Renvoi de vérification ─────────────────────────────────────────────────
# Ces méthodes ne retournent plus rien et ne lèvent plus rien : l'appelant ne
# doit pas pouvoir distinguer les trois états. On vérifie donc l'effet de bord
# (email envoyé ou non), seul comportement observable qui reste.
def test_resend_verification_unknown_sends_nothing():
    svc = _service()
    svc.users.get_by_email.return_value = None
    assert svc.resend_verification("nobody@example.com") is None
    svc.notifier.send_verification_email.assert_not_called()


def test_resend_verification_already_verified_is_silent():
    svc = _service()
    svc.users.get_by_email.return_value = SimpleNamespace(is_email_verified=True)
    # Ne lève pas : un ALREADY_VERIFIED révélerait un troisième état distinguable.
    assert svc.resend_verification("user@example.com") is None
    svc.notifier.send_verification_email.assert_not_called()


def test_resend_verification_unverified_sends():
    svc = _service()
    svc.users.get_by_email.return_value = SimpleNamespace(
        is_email_verified=False, email="user@example.com", full_name="U",
        verification_token=None, verification_token_expires_at=None,
    )
    assert svc.resend_verification("user@example.com") is None
    svc.notifier.send_verification_email.assert_called_once()


# ── Mot de passe oublié / reset ────────────────────────────────────────────
def test_forgot_password_unknown_sends_nothing():
    svc = _service()
    svc.users.get_by_email.return_value = None
    assert svc.forgot_password("nobody@example.com") is None
    svc.notifier.send_password_reset_email.assert_not_called()


def test_forgot_password_known_sends():
    svc = _service()
    svc.users.get_by_email.return_value = SimpleNamespace(
        email="user@example.com", full_name="U",
        reset_password_token=None, reset_token_expires_at=None,
    )
    assert svc.forgot_password("user@example.com") is None
    svc.notifier.send_password_reset_email.assert_called_once()


def test_reset_password_expired_token_raises():
    svc = _service()
    svc.users.get_by_reset_token.return_value = SimpleNamespace(
        reset_token_expires_at=datetime.utcnow() - timedelta(hours=1),
    )
    with pytest.raises(BadRequestError) as exc:
        svc.reset_password("t", "newpass123")
    assert exc.value.error_code == "TOKEN_EXPIRED"


def test_reset_password_success_updates_hash_and_confirms():
    svc = _service()
    user = SimpleNamespace(
        reset_token_expires_at=datetime.utcnow() + timedelta(hours=1),
        password_hash=hash_password("oldpass"),
        reset_password_token="t", email="user@example.com", full_name="U",
        token_version=0,
    )
    svc.users.get_by_reset_token.return_value = user
    result = svc.reset_password("t", "newpass123")
    assert result.password_hash != hash_password("oldpass")  # hash changé
    assert result.reset_password_token is None
    # Un mot de passe changé après un vol de token doit révoquer les sessions.
    assert result.token_version == 1
    svc.notifier.send_password_changed_confirmation.assert_called_once()


# ── Complétion de profil ───────────────────────────────────────────────────
def test_profile_completion_tourist_all_fields_is_100():
    user = SimpleNamespace(
        full_name="U", email="u@example.com", phone="0612345678",
        date_of_birth="1990-01-01", is_email_verified=True,
    )
    assert AuthService._profile_completion(user, None) == 100


def test_profile_completion_tourist_partial_is_below_100():
    user = SimpleNamespace(
        full_name="U", email="u@example.com", phone=None,
        date_of_birth=None, is_email_verified=False,
    )
    # 2 champs / 5 remplis
    assert AuthService._profile_completion(user, None) == 40
