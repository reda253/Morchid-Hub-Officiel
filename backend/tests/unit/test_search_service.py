"""Tests unitaires du SearchService — agrégation des valeurs de filtres."""

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.services.search_service import SearchService

pytestmark = pytest.mark.unit


def _service():
    svc = SearchService(db=MagicMock())
    svc.guides = MagicMock()
    return svc


def test_available_filters_dedupes_and_sorts():
    svc = _service()
    svc.guides.list_approved.return_value = [
        SimpleNamespace(
            cities_covered=["Marrakech", "Fès"],
            specialties=["culture"],
            languages=["Français", "Arabe"],
        ),
        SimpleNamespace(
            cities_covered=["Fès"],           # doublon ville
            specialties=["nature", "culture"],  # doublon spécialité
            languages=["Anglais"],
        ),
    ]

    result = svc.available_filters()

    assert result["cities"] == ["Fès", "Marrakech"]        # trié, dédupliqué
    assert result["specialties"] == ["culture", "nature"]
    assert result["languages"] == ["Anglais", "Arabe", "Français"]
    assert result["total_guides"] == 2


def test_available_filters_handles_empty_fields():
    svc = _service()
    svc.guides.list_approved.return_value = [
        SimpleNamespace(cities_covered=None, specialties=None, languages=None),
    ]
    result = svc.available_filters()
    assert result["cities"] == []
    assert result["total_guides"] == 1


def test_search_guides_delegates_to_repository():
    svc = _service()
    svc.guides.search_guides.return_value = ["row"]
    out = svc.search_guides(city="Fès", limit=5)
    assert out == ["row"]
    svc.guides.search_guides.assert_called_once_with(city="Fès", limit=5)
