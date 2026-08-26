"""Service des profils guides : vérification d'identité et consultation."""

import os
from typing import List

from fastapi import UploadFile
from sqlalchemy.orm import Session

from ..exceptions import BadRequestError, ForbiddenError, NotFoundError, ServerError
from ..models import Guide, User
from ..repositories.guide_repository import GuideRepository
from ..uploads import (
    ALLOWED_IMAGE_EXTENSIONS,
    CINE_DIR,
    LICENSE_DIR,
    PROFILE_DIR,
    save_upload_file,
)


class GuideService:
    def __init__(self, db: Session):
        self.db = db
        self.guides = GuideRepository(db)

    def list_guides(self, skip: int, limit: int) -> List[Guide]:
        return self.guides.list_paginated(skip=skip, limit=limit)

    def submit_verification(
        self,
        current_user: User,
        *,
        cine_number: str,
        license_number: str,
        profile_photo: UploadFile,
        license_photo: UploadFile,
        cine_photo: UploadFile,
    ) -> dict:
        if current_user.role != "guide":
            raise ForbiddenError(
                "NOT_A_GUIDE",
                "Seuls les guides peuvent soumettre des documents de vérification",
            )

        guide = self.guides.get_by_user_id(current_user.id)
        if not guide:
            raise NotFoundError("GUIDE_PROFILE_NOT_FOUND", "Profil guide non trouvé")

        if guide.is_verified:
            raise BadRequestError("ALREADY_VERIFIED", "Votre compte est déjà vérifié")

        for file in (profile_photo, license_photo, cine_photo):
            ext = os.path.splitext(file.filename)[1].lower()
            if ext not in ALLOWED_IMAGE_EXTENSIONS:
                raise BadRequestError(
                    "INVALID_FILE_FORMAT",
                    f"Format de fichier non supporté: {file.filename}. Utilisez JPG, PNG ou WEBP.",
                )

        try:
            profile_photo_path = save_upload_file(profile_photo, PROFILE_DIR)
            license_photo_path = save_upload_file(license_photo, LICENSE_DIR)
            cine_photo_path = save_upload_file(cine_photo, CINE_DIR)
        except Exception as e:
            raise ServerError(
                "FILE_SAVE_ERROR", f"Erreur lors de la sauvegarde des fichiers: {str(e)}"
            )

        try:
            guide.cine_number = cine_number
            guide.license_number = license_number
            guide.profile_photo_url = profile_photo_path
            guide.license_card_url = license_photo_path
            guide.cine_card_url = cine_photo_path
            guide.has_official_license = True
            # RG14 : le statut reste `pending` ; la soumission des documents est
            # tracée par has_official_license (sous-état "DocumentsSoumis").
            guide.approval_status = "pending"
            self.db.commit()
            self.db.refresh(guide)
        except Exception as e:
            self.db.rollback()
            raise ServerError("DATABASE_ERROR", f"Erreur lors de la mise à jour: {str(e)}")

        return {
            "guide_id": guide.id,
            "approval_status": guide.approval_status,
            "cine_number": cine_number,
            "license_number": license_number,
            "profile_photo_url": f"/{profile_photo_path}",
            "license_photo_url": f"/{license_photo_path}",
            "cine_photo_url": f"/{cine_photo_path}",
        }

    def get_public_guide(self, guide_id: str):
        """Guide approuvé par id, ou None si absent ou non approuvé."""
        guide = self.guides.get_by_id(guide_id)
        if guide is None or guide.approval_status != "approved":
            return None
        return guide
