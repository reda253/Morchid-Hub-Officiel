"""Un appelant anonyme ne doit pas pouvoir distinguer un compte existant d'un
compte inconnu. Trois états doivent être indiscernables : inconnu, connu non
vérifié, connu déjà vérifié."""

import pytest

from tests.factories import make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


def _resend(client, email):
    return client.post("/api/v1/auth/resend-verification", json={"email": email})


def _forgot(client, email):
    return client.post("/api/v1/auth/forgot-password", json={"email": email})


def test_resend_verification_is_indistinguishable(client, db_session):
    unverified = make_user(db_session, is_email_verified=False)
    verified = make_user(db_session, is_email_verified=True)

    responses = [
        _resend(client, "inconnu.plan.test@example.com"),
        _resend(client, unverified.email),
        _resend(client, verified.email),
    ]

    codes = {r.status_code for r in responses}
    bodies = {r.text for r in responses}
    assert codes == {200}, f"statuts distinguables : {codes}"
    assert len(bodies) == 1, f"corps de réponse distinguables : {bodies}"


def test_forgot_password_is_indistinguishable(client, db_session):
    known = make_user(db_session)

    responses = [
        _forgot(client, "inconnu.plan.test@example.com"),
        _forgot(client, known.email),
    ]

    assert {r.status_code for r in responses} == {200}
    assert len({r.text for r in responses}) == 1, "le champ data trahit l'existence du compte"
