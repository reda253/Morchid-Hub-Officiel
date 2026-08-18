"""Service de recherche et découverte (lecture seule)."""

from typing import List, Optional, Tuple

from sqlalchemy.orm import Session

from ..models import Guide, GuideRoute, User
from ..repositories.guide_repository import GuideRepository


class SearchService:
    def __init__(self, db: Session):
        self.db = db
        self.guides = GuideRepository(db)

    def search_guides(self, **filters) -> List[Tuple[User, Guide]]:
        return self.guides.search_guides(**filters)

    def search_guides_with_routes(self, **filters) -> List[Tuple[User, Guide, Optional[GuideRoute]]]:
        return self.guides.search_guides_with_routes(**filters)

    def available_filters(self) -> dict:
        guides = self.guides.list_approved()
        cities: set = set()
        specialties: set = set()
        languages: set = set()
        for guide in guides:
            if guide.cities_covered:
                cities.update(guide.cities_covered)
            if guide.specialties:
                specialties.update(guide.specialties)
            if guide.languages:
                languages.update(guide.languages)
        return {
            "cities": sorted(cities),
            "specialties": sorted(specialties),
            "languages": sorted(languages),
            "total_guides": len(guides),
        }
