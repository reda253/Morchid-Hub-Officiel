"""Validation des fichiers uploadés (documents de vérification guide)."""

import io

import pytest
from fastapi import UploadFile

from app.exceptions import BadRequestError
from app.uploads import MAX_UPLOAD_BYTES, save_upload_file

pytestmark = [pytest.mark.unit]

JPEG_MAGIC = b"\xff\xd8\xff\xe0"


def _upload(filename: str, content: bytes) -> UploadFile:
    return UploadFile(filename=filename, file=io.BytesIO(content))


def test_rejects_disallowed_extension(tmp_path):
    with pytest.raises(BadRequestError) as exc:
        save_upload_file(_upload("malware.exe", JPEG_MAGIC), tmp_path)
    assert exc.value.error_code == "INVALID_EXTENSION"


def test_rejects_extension_mismatched_content(tmp_path):
    """Une extension autorisée ne suffit pas : le contenu doit être une image."""
    with pytest.raises(BadRequestError) as exc:
        save_upload_file(_upload("piege.jpg", b"#!/bin/sh\nrm -rf /"), tmp_path)
    assert exc.value.error_code == "INVALID_FILE_TYPE"


def test_rejects_oversized_file(tmp_path):
    payload = JPEG_MAGIC + b"0" * (MAX_UPLOAD_BYTES + 1)
    with pytest.raises(BadRequestError) as exc:
        save_upload_file(_upload("enorme.jpg", payload), tmp_path)
    assert exc.value.error_code == "FILE_TOO_LARGE"


def test_accepts_valid_jpeg(tmp_path):
    stored = save_upload_file(_upload("licence.jpg", JPEG_MAGIC + b"contenu"), tmp_path)
    assert stored.endswith(".jpg")
    assert "/" in stored


def test_returns_a_relative_forward_slash_path():
    """Le chemin retourné est relatif à backend/ et utilise des '/'.

    L'ancienne implémentation faisait `relative_to(Path("."))` sur un chemin
    absolu, ce qui levait ValueError après avoir déjà écrit le fichier : tout
    upload réel échouait en 500.
    """
    from app.uploads import PROFILE_DIR, ensure_upload_dirs

    ensure_upload_dirs()
    stored = save_upload_file(_upload("photo.png", b"\x89PNG\r\n\x1a\n suite"), PROFILE_DIR)

    assert stored.startswith("uploads/profiles/")
    assert "\\" not in stored
