"""token_version — révocation immédiate des JWT émis avant un incrément."""

import pytest

from app.auth import create_access_token, decode_access_token

pytestmark = [pytest.mark.unit]


def test_token_carries_version_claim():
    token = create_access_token(
        {"sub": "u1", "email": "a@b.c", "role": "tourist", "tv": 3}
    )
    assert decode_access_token(token)["tv"] == 3
