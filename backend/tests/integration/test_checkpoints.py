"""Tests d'intégration — table `checkpoints` (promotion du JSON, dual-write)."""

import pytest

from app.models import Checkpoint
from tests.factories import auth_headers, make_guide, make_route, make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


_CHECKPOINTS = [
    {
        "id": "cp-1",
        "name": "Place Jemaa el-Fna",
        "description": "Coeur historique de Marrakech.",
        "lat": 31.6258,
        "lng": -7.9892,
        "type": "Monument",
        "estimated_time": 30,
        "image_url": None,
    },
    {
        "id": "cp-2",
        "name": "Jardin Majorelle",
        "description": "Jardin botanique emblématique.",
        "lat": 31.6417,
        "lng": -7.9986,
        "type": "Panorama",
        "estimated_time": 20,
        "image_url": None,
    },
]


def test_build_route_populates_checkpoint_table(db_session):
    guide = make_guide(db_session)
    route = make_route(db_session, guide=guide, checkpoints=_CHECKPOINTS)
    db_session.flush()

    rows = (
        db_session.query(Checkpoint)
        .filter(Checkpoint.route_id == route.id)
        .order_by(Checkpoint.position)
        .all()
    )
    assert len(rows) == 2
    assert rows[0].name == "Place Jemaa el-Fna"
    assert rows[0].position == 0
    assert rows[1].type == "Panorama"
    # La colonne JSON reste alimentée (compat réponse).
    assert len(route.checkpoints) == 2


def test_create_route_api_writes_checkpoints(client, db_session):
    guide_user = make_user(db_session, role="guide")
    make_guide(db_session, user=guide_user)

    body = {
        "coordinates": [{"lat": 31.62, "lng": -7.98}, {"lat": 31.63, "lng": -7.99}],
        "start_point": {"lat": 31.62, "lng": -7.98},
        "end_point": {"lat": 31.63, "lng": -7.99},
        "distance": 2.5,
        "duration": 30.0,
        "checkpoints": _CHECKPOINTS,
    }
    resp = client.post(
        "/api/v1/guides/routes", json=body, headers=auth_headers(guide_user)
    )
    assert resp.status_code == 201
    route_id = resp.json()["id"]

    count = (
        db_session.query(Checkpoint).filter(Checkpoint.route_id == route_id).count()
    )
    assert count == 2
