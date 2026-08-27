"""Tests unitaires de la garde `require_admin` et de la liste blanche admin.

La source de vérité de l'autorisation admin est la configuration
(`ADMIN_EMAILS`), plus la base de données : ni `is_admin` ni le rôle
`administrator` ne doivent ouvrir l'accès.
"""

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.api.deps import require_admin
from app.auth import hash_password
from app.config import Settings, settings
from app.exceptions import ForbiddenError
from app.services.auth_service import AuthService

pytestmark = pytest.mark.unit


@pytest.fixture
def allowlist(monkeypatch):
    """Remplace ADMIN_EMAILS le temps d'un test."""

    def _set(value: str):
        monkeypatch.setattr(settings, "ADMIN_EMAILS", value, raising=False)

    return _set


def _user(email, *, is_admin=False, role="tourist"):
    return SimpleNamespace(id="u1", email=email, is_admin=is_admin, role=role)


# ── Parsing de la liste blanche ────────────────────────────────────────────
def test_admin_emails_list_parses_and_lowercases():
    s = Settings(DATABASE_URL="sqlite://", SECRET_KEY="x", ADMIN_EMAILS="A@B.com, c@D.com")
    assert s.admin_emails_list == ["a@b.com", "c@d.com"]


def test_admin_emails_list_empty_when_unset():
    s = Settings(DATABASE_URL="sqlite://", SECRET_KEY="x", ADMIN_EMAILS="")
    assert s.admin_emails_list == []


def test_admin_emails_list_drops_blank_entries():
    s = Settings(DATABASE_URL="sqlite://", SECRET_KEY="x", ADMIN_EMAILS="a@b.com, ,,")
    assert s.admin_emails_list == ["a@b.com"]


# ── Garde require_admin ────────────────────────────────────────────────────
def test_allowlisted_email_is_accepted(allowlist):
    allowlist("boss@example.com")
    user = _user("boss@example.com")
    assert require_admin(user) is user


def test_db_flags_do_not_grant_access(allowlist):
    """Régression : `is_admin=True` + rôle `administrator` en base ne suffisent plus.

    C'est tout l'objet du changement — l'écriture en base ne fabrique pas d'admin.
    """
    allowlist("boss@example.com")
    impostor = _user("attacker@example.com", is_admin=True, role="administrator")
    with pytest.raises(ForbiddenError) as exc:
        require_admin(impostor)
    assert exc.value.error_code == "FORBIDDEN"
    assert exc.value.status_code == 403


def test_comparison_is_case_insensitive(allowlist):
    allowlist("foo@bar.com")
    user = _user("Foo@Bar.com")
    assert require_admin(user) is user


def test_surrounding_whitespace_is_ignored(allowlist):
    allowlist("foo@bar.com")
    user = _user("  foo@bar.com  ")
    assert require_admin(user) is user


def test_null_email_is_rejected_without_crashing(allowlist):
    """La colonne email est nullable (models.py) : pas d'AttributeError."""
    allowlist("boss@example.com")
    with pytest.raises(ForbiddenError) as exc:
        require_admin(_user(None, is_admin=True, role="administrator"))
    assert exc.value.error_code == "FORBIDDEN"


def test_empty_allowlist_rejects_everyone(allowlist):
    """Fail closed : sans ADMIN_EMAILS configuré, personne n'est admin."""
    allowlist("")
    with pytest.raises(ForbiddenError):
        require_admin(_user("boss@example.com", is_admin=True, role="administrator"))


def test_non_allowlisted_email_is_rejected(allowlist):
    allowlist("boss@example.com, second@example.com")
    with pytest.raises(ForbiddenError):
        require_admin(_user("someone@example.com"))


# ── Synchronisation de la colonne cache `is_admin` à la connexion ──────────
def _auth_service():
    svc = AuthService(db=MagicMock())
    svc.users = MagicMock()
    svc.guides = MagicMock()
    svc.notifier = MagicMock()
    return svc


def _login_user(email, is_admin):
    return SimpleNamespace(
        id="u1", email=email, role="tourist", is_admin=is_admin,
        password_hash=hash_password("goodpass"), is_active=True, token_version=0,
    )


def test_login_sets_is_admin_true_for_allowlisted_email(allowlist):
    allowlist("Boss@Example.com")
    svc = _auth_service()
    user = _login_user("boss@example.com", is_admin=False)
    svc.users.get_by_email.return_value = user
    svc.login("boss@example.com", "goodpass")
    assert user.is_admin is True


def test_login_clears_stale_is_admin_for_non_allowlisted_email(allowlist):
    """Colonne obsolète en base : la connexion la remet à False."""
    allowlist("boss@example.com")
    svc = _auth_service()
    user = _login_user("attacker@example.com", is_admin=True)
    svc.users.get_by_email.return_value = user
    svc.login("attacker@example.com", "goodpass")
    assert user.is_admin is False
