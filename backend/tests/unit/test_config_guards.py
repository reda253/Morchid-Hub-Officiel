"""Gardes de configuration — refus de démarrer avec des réglages non sûrs."""

import pytest

pytestmark = [pytest.mark.unit]


def test_weak_secret_key_is_rejected():
    from app.main import _assert_secret_key_is_safe

    with pytest.raises(RuntimeError, match="SECRET_KEY"):
        _assert_secret_key_is_safe("votre_cle_secrete_super_longue_et_aleatoire_ici")

    with pytest.raises(RuntimeError, match="SECRET_KEY"):
        _assert_secret_key_is_safe("court")


def test_strong_secret_key_is_accepted():
    from app.main import _assert_secret_key_is_safe

    _assert_secret_key_is_safe("v" + "V4l1de" * 10)


def test_debug_defaults_to_false():
    from app.config import Settings

    assert Settings.model_fields["DEBUG"].default is False
