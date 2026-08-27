"""
Gestion du stockage des fichiers uploadés (photos de vérification guide).

Centralise la configuration des dossiers d'upload et la sauvegarde disque,
extraites de l'ancien `main.py`. Les chemins sont absolus, basés sur
l'emplacement du package (`backend/uploads`).
"""

import os
import uuid
from pathlib import Path

from fastapi import UploadFile

from .exceptions import BadRequestError

# backend/app/uploads.py -> backend/uploads
BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"

PROFILE_DIR = UPLOAD_DIR / "profiles"
LICENSE_DIR = UPLOAD_DIR / "licenses"
CINE_DIR = UPLOAD_DIR / "cines"

# Extensions d'image autorisées pour les documents de vérification
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

# Taille maximale d'un document de vérification (5 Mio).
MAX_UPLOAD_BYTES = 5 * 1024 * 1024

# Signatures de fichiers acceptées (magic bytes), par famille d'image.
# L'extension seule ne prouve rien : elle est choisie par le client.
_IMAGE_SIGNATURES = (
    b"\xff\xd8\xff",          # JPEG
    b"\x89PNG\r\n\x1a\n",     # PNG
    b"RIFF",                  # WEBP (conteneur RIFF)
)


def ensure_upload_dirs() -> None:
    """Crée l'arborescence uploads/ si elle n'existe pas (idempotent)."""
    for directory in (UPLOAD_DIR, PROFILE_DIR, LICENSE_DIR, CINE_DIR):
        directory.mkdir(exist_ok=True)


def save_upload_file(upload_file: UploadFile, destination: Path) -> str:
    """
    Sauvegarde un fichier uploadé sous un nom unique, après validation.

    Trois contrôles, dans cet ordre : extension autorisée, taille maximale,
    puis signature du contenu. Le dernier est le seul qui prouve quelque chose —
    l'extension et le type MIME déclaré viennent tous deux du client.

    Returns:
        Chemin relatif (avec des '/') du fichier sauvegardé,
        ex: "uploads/profiles/<uuid>.jpg".

    Raises:
        BadRequestError: extension refusée, fichier trop volumineux, ou contenu
        qui n'est pas une image.
    """
    file_extension = os.path.splitext(upload_file.filename or "")[1].lower()
    if file_extension not in ALLOWED_IMAGE_EXTENSIONS:
        raise BadRequestError(
            "INVALID_EXTENSION",
            f"Format non autorisé. Formats acceptés : "
            f"{', '.join(sorted(ALLOWED_IMAGE_EXTENSIONS))}",
        )

    content = upload_file.file.read()
    if len(content) > MAX_UPLOAD_BYTES:
        raise BadRequestError(
            "FILE_TOO_LARGE",
            f"Fichier trop volumineux (maximum {MAX_UPLOAD_BYTES // (1024 * 1024)} Mio)",
        )

    if not content.startswith(_IMAGE_SIGNATURES):
        raise BadRequestError(
            "INVALID_FILE_TYPE",
            "Le fichier envoyé n'est pas une image valide",
        )

    unique_filename = f"{uuid.uuid4()}{file_extension}"
    file_path = destination / unique_filename
    file_path.write_bytes(content)

    # Le chemin rendu est relatif à backend/, pour être servi tel quel sous
    # /uploads/profiles. `relative_to(Path("."))` échouait ici : les dossiers
    # d'upload sont absolus, donc chaque upload réel levait ValueError *après*
    # avoir écrit le fichier.
    try:
        relative = file_path.relative_to(BASE_DIR)
    except ValueError:
        # Destination hors de backend/ (tests) : les deux derniers segments
        # suffisent à identifier le fichier.
        relative = Path(destination.name) / unique_filename

    return str(relative).replace(os.path.sep, "/")
