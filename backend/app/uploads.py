"""
Gestion du stockage des fichiers uploadés (photos de vérification guide).

Centralise la configuration des dossiers d'upload et la sauvegarde disque,
extraites de l'ancien `main.py`. Les chemins sont absolus, basés sur
l'emplacement du package (`backend/uploads`).
"""

import os
import shutil
import uuid
from pathlib import Path

from fastapi import UploadFile

# backend/app/uploads.py -> backend/uploads
BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"

PROFILE_DIR = UPLOAD_DIR / "profiles"
LICENSE_DIR = UPLOAD_DIR / "licenses"
CINE_DIR = UPLOAD_DIR / "cines"

# Extensions d'image autorisées pour les documents de vérification
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def ensure_upload_dirs() -> None:
    """Crée l'arborescence uploads/ si elle n'existe pas (idempotent)."""
    for directory in (UPLOAD_DIR, PROFILE_DIR, LICENSE_DIR, CINE_DIR):
        directory.mkdir(exist_ok=True)


def save_upload_file(upload_file: UploadFile, destination: Path) -> str:
    """
    Sauvegarde un fichier uploadé sous un nom unique.

    Returns:
        Chemin relatif (avec des '/') du fichier sauvegardé,
        ex: "uploads/profiles/<uuid>.jpg".
    """
    file_extension = os.path.splitext(upload_file.filename)[1]
    unique_filename = f"{uuid.uuid4()}{file_extension}"
    file_path = destination / unique_filename

    with file_path.open("wb") as buffer:
        shutil.copyfileobj(upload_file.file, buffer)

    return str(file_path.relative_to(Path("."))).replace(os.path.sep, "/")
