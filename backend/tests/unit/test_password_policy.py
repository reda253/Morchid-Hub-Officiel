"""Politique de mot de passe — plancher à 10 caractères, lettres + chiffres."""

import pytest

from app.auth import validate_password_strength

pytestmark = [pytest.mark.unit]


@pytest.mark.parametrize("password", ["court1", "abc12", "azerty1"])
def test_rejects_short_passwords(password):
    valid, message = validate_password_strength(password)
    assert valid is False
    assert "10" in message


def test_rejects_letters_only():
    valid, _ = validate_password_strength("azertyuiopqsdfgh")
    assert valid is False


def test_accepts_strong_password():
    valid, _ = validate_password_strength("Marrakech2026")
    assert valid is True
