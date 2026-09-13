"""Traduction des URL Postgres managées (format libpq) pour le pilote pg8000."""

import ssl

import pytest

from app.db_url import build_engine_config

pytestmark = [pytest.mark.unit]

NEON_HOST = "ep-cool-lab-123456.eu-central-1.aws.neon.tech"


def test_url_without_query_is_unchanged():
    url, connect_args = build_engine_config(
        "postgresql+pg8000://morchid:motdepasse@db:5432/morchid"
    )

    assert url.host == "db"
    assert url.database == "morchid"
    assert dict(url.query) == {}
    assert connect_args == {}


def test_sslmode_require_becomes_verified_ssl_context():
    url, connect_args = build_engine_config(
        f"postgresql+pg8000://u:p@{NEON_HOST}/neondb?sslmode=require"
    )

    assert "sslmode" not in url.query
    context = connect_args["ssl_context"]
    assert isinstance(context, ssl.SSLContext)
    assert context.verify_mode == ssl.CERT_REQUIRED
    assert context.check_hostname is True


def test_channel_binding_is_stripped():
    url, connect_args = build_engine_config(
        f"postgresql+pg8000://u:p@{NEON_HOST}/neondb?sslmode=require&channel_binding=require"
    )

    assert dict(url.query) == {}
    assert "ssl_context" in connect_args


def test_unrelated_query_params_survive():
    url, _ = build_engine_config(
        f"postgresql+pg8000://u:p@{NEON_HOST}/neondb?application_name=morchid&sslmode=require"
    )

    assert dict(url.query) == {"application_name": "morchid"}


def test_sslmode_disable_is_stripped_without_tls():
    url, connect_args = build_engine_config(
        "postgresql+pg8000://u:p@localhost:5432/morchid?sslmode=disable"
    )

    assert dict(url.query) == {}
    assert connect_args == {}


def test_unsupported_sslmode_is_rejected_without_leaking_password():
    with pytest.raises(ValueError, match="sslmode") as excinfo:
        build_engine_config(
            f"postgresql+pg8000://u:S3cretNeon@{NEON_HOST}/neondb?sslmode=prefer"
        )

    assert "S3cretNeon" not in str(excinfo.value)
    assert NEON_HOST not in str(excinfo.value)


def test_password_survives_translation():
    # str(URL) masque le mot de passe en « *** » : si la fonction repassait par
    # une chaîne, l'engine se connecterait avec « *** » et l'échec serait obscur.
    url, _ = build_engine_config(
        f"postgresql+pg8000://u:S3cretNeon@{NEON_HOST}/neondb?sslmode=require"
    )

    assert url.password == "S3cretNeon"
