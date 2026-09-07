# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Last verified against the code: 2026-09-08.** Facts below carry file:line references. If a
reference does not resolve, the file moved — re-check before trusting the claim.

## Project Overview

Morchid Hub is a sustainable-tourism platform for Morocco connecting verified official guides with
tourists. FastAPI + PostgreSQL/PostGIS backend, Flutter mobile client, monorepo with `backend/` and
`frontend/` side by side.

The Dart package is named **`morchid_hub`**, not `frontend` — imports are
`package:morchid_hub/...`.

Three domain concepts recur across nearly every endpoint and screen:

- **Guide approval workflow.** `Guide.approval_status` is one of exactly three values:
  `pending` → `approved` | `rejected` (`models.py:40`, default `'pending'`). There is no
  `pending_approval` or `pending_review` state. A guide is invisible to tourists until approved.
- **Geospatial routes.** PostGIS `LINESTRING`/`POINT` geometries at SRID 4326, read and written
  through `shapely` + `geoalchemy2.shape.from_shape`/`to_shape`.
- **Premium tier.** `Guide.is_premium` / `premium_until`, checked via `Guide.is_premium_active()`.
  Free guides are capped at `FREE_ROUTE_LIMIT = 2` active routes
  (`services/route_service.py:13,32`).

## Commands

### Backend (from `backend/`)

```bash
source venv/Scripts/activate        # or fastapi_venv/Scripts/activate
pip install -r requirements.txt     # runtime only — what the image installs
pip install -r requirements-dev.txt # runtime + pytest/httpx/pytest-cov

uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

alembic upgrade head                # apply migrations (the real schema path)
alembic current                     # show the current revision
alembic downgrade -1                # step back one

pytest                              # full suite — 187 tests
pytest -m unit                      # services with mocked repos, no DB needed
pytest -m integration               # repositories + API, needs PostGIS
pytest tests/integration/test_api_auth.py -v      # single file
```

There are **no one-off scripts at the root of `backend/`** — `create_db.py`, `drop_tables.py`,
`approve_all_guides.py` and the old ad-hoc `test_*.py` / `simulate_*.py` files are gone. Use
Alembic for schema and the pytest suite for verification.

### Docker (from the repo root)

```bash
cp .env.example .env                # then fill SECRET_KEY (≥ 32 chars, no placeholder)
docker compose up --build           # PostGIS on 127.0.0.1:5432 + API on :8000

docker compose -f docker-compose.test.yml up -d   # throwaway PostGIS on 127.0.0.1:5433
```

Two Compose files, each with its own project `name` (`morchid`, `morchid-test`) so the stacks can
run side by side without orphan-container warnings. Both publish Postgres on `127.0.0.1` only —
never widen that to `5432:5432`.

- `backend/Dockerfile` — two stages (`builder` builds a venv from `requirements.txt`, `runtime`
  copies it). Runs as non-root `appuser`; every runtime dependency ships a manylinux wheel, so the
  image needs no compiler and no `libpq-dev`. That is why `pg8000` is the pinned driver.
- `backend/docker-entrypoint.sh` — wait for the database, `alembic upgrade head`, then
  `exec uvicorn`. `exec` makes uvicorn PID 1 so `docker stop` reaches it. The wait loop logs only
  the exception *type*: SQLAlchemy/pg8000 errors carry the host, port, database, user, and a
  malformed `DATABASE_URL` can surface the password in cleartext.
- `.env.example` is the committed template for the Compose-level variables; `.env` stays
  gitignored.
- Uploads live in a **named volume**, never a bind mount of `./backend/uploads` — the guides'
  identity scans must not travel from a dev machine into another environment.

### CI/CD (`.github/workflows/`)

- **`ci.yml`** runs on pull requests and pushes. Three blocking jobs: `backend-tests` (pytest
  against a `postgis/postgis:16-3.4` service container, then `alembic upgrade head` on a clean
  database), `frontend-tests` (`flutter analyze --no-fatal-infos --no-fatal-warnings`, then
  `flutter test`), and `docker-build`.
- The backend job asserts **`tests ≥ 187` and `skipped == 0`** from the JUnit report. Integration
  tests self-skip when no database is reachable, so a misconfigured service container would
  otherwise report a green, nearly empty suite. The migration-chain step exists because the test
  fixtures build their schema with `create_all` and therefore never exercise Alembic.
- **`cd.yml`** runs on pushes to `main`: build and push `ghcr.io/<owner>/morchid-hub-api`, tagged
  with the long commit SHA and `latest`. Auth is the workflow-scoped `GITHUB_TOKEN` with
  `packages: write` — no personal access token. There is no deploy step; Plan 05 owns the host.

### Frontend (from `frontend/`)

```bash
flutter pub get
flutter run
flutter analyze                     # baseline: 130 issues, 0 error-severity
flutter test                        # 61 tests across 14 files under test/
flutter test test/widgets/ui_kit_avatar_test.dart   # single file
```

`baseUrl` is hardcoded and switches by platform (`services/api_service.dart:24-28`):
`http://10.0.2.2:8000` on the Android emulator, `http://127.0.0.1:8000` elsewhere. There is no
`.env` on the Flutter side — edit `baseUrl` to target another host.

## Architecture

### Backend — layered (`backend/app/`)

The Plan 01 refactor is complete. `main.py` is a **72-line app factory** and holds no business
logic. Layers:

```
api/          HTTP only — routing, request/response shapes, auth dependencies
services/     business rules — the layer that owns decisions
repositories/ data access — SQLAlchemy queries, nothing else
```

| Path | Role |
|---|---|
| `main.py` | `create_app()`: CORS, static mount, nine routers, exception handlers, and a `create_all` bootstrap that is **gated on `settings.DEBUG`** (`:99`). Outside DEBUG, `alembic upgrade head` is the only schema authority |
| `api/` | Nine routers: `auth`, `guides`, `routes`, `premium`, `reviews`, `admin`, `search`, `time_slots`, `health` |
| `api/deps.py` | Service providers + `require_admin` (`:62`) |
| `services/` | Ten services, one per domain |
| `repositories/` | Seven repositories + `base.py` |
| `models.py` | SQLAlchemy models. `User`/`Guide` ids are **string UUIDs**, not integers |
| `schemas.py` | Pydantic v2. Phone validation enforces Moroccan formats (`+212[5-7]\d{8}` or `0[5-7]\d{8}`) |
| `auth.py` | JWT + hashing + `get_current_user` (`:144`) + `is_admin_email` (`:212`) |
| `exceptions.py` | `AppError` hierarchy + the three handlers; all errors share one JSON envelope |
| `uploads.py` | Upload dirs and disk writes |
| `config.py` | `pydantic-settings` over `.env` |
| `alembic/versions/` | `0001`–`0007` |
| `rate_limit.py` | `limiter`, the 429 handler, and the single place slowapi is imported |

**Endpoint count: 43.** The two added by the security work are
`GET /api/v1/guides/{id}/contact` (any logged-in user) and
`GET /api/v1/admin/guides/{id}/documents/{type}` (admin only).

Router prefixes: `/api/v1/admin/*`, `/api/v1/search/*`, `/api/v1/*` for everything else.

**Hashing is `pbkdf2_sha256`, not bcrypt** (`auth.py:18`), despite `passlib[bcrypt]` being
installed. Do not change the algorithm without a migration plan for existing hashes.

`DATABASE_URL` uses the **`postgresql+pg8000://`** driver. `psycopg2-binary` has been **removed**
from `requirements.txt` — it was never imported, and keeping two drivers invites someone to flip
`DATABASE_URL` back and rediscover the problem from the other end. `pg8000` is pure Python, which
is what lets the image build with no compiler and no `libpq-dev`.

Dependencies are split: `requirements.txt` is the runtime (what the Docker image installs) and
`requirements-dev.txt` pulls it in via `-r` and adds `pytest`, `httpx`, `pytest-asyncio`,
`pytest-cov`. Every version is pinned — an unpinned dependency means two builds of the same commit
can differ.

### Backend tests (`backend/tests/`)

187 tests. `conftest.py` provides:

- `db_session` — a real PostGIS test database, isolated per test by a savepoint-based transaction
  rollback. Service `commit()` calls become savepoints; nothing leaks between tests.
- `client` — `TestClient` with `get_db` overridden onto that session. Deliberately built without
  `with`, so the lifespan (and its `create_all` against the *production* engine) never fires.
- `admin_user` — an admin by `ADMIN_EMAILS` whitelist only; its `role` stays `tourist` and
  `is_admin` stays `False` on purpose, so that reintroducing either into `require_admin` breaks
  these tests instead of silently passing.
- `factories.py` — `make_user`, `make_guide`, `make_route`, `make_review`,
  `make_support_message`, `make_subscription`, `auth_headers`.

**Integration tests self-skip when no test database is reachable.** A skipped integration suite is
not a passing one — check that the DB is up before trusting a green run. CI enforces this: the
`backend-tests` job fails on any skip (see CI/CD above).

### Frontend (`frontend/lib/`)

The Stitch design system and the three-phase restyle are complete.

| Path | Role |
|---|---|
| `main.dart` | `MaterialApp` + `onGenerateRoute`; the **only** file allowed to construct routes |
| `routes/app_routes.dart` | Route-name constants and typed argument classes (`MapArgs`, `ReviewArgs`, `PaymentArgs`, `GuideProfileArgs`, `EmailVerificationArgs`) |
| `shell/` | `main_shell.dart` + `shell_destinations.dart` — the bottom-nav shell at `/shell` |
| `theme/` | `app_theme.dart`, `app_text_styles.dart` |
| `utils/` | `app_colors.dart`, `validators.dart` |
| `widgets/ui_kit.dart` | Shared components — prefer these over private per-screen duplicates |
| `widgets/` | `auth_guard.dart`, `error_state.dart`, `inline_error.dart`, plus feature widgets |
| `screens/` | 20 screens, one file each |
| `services/api_service.dart` | The single HTTP client; endpoints are class constants; auth via `_getAuthHeaders` reading the JWT from `storage_service.dart` (SharedPreferences) |
| `services/osm_service.dart` | OSRM/Nominatim helpers for the map |
| `models/` | Dart mirrors of the backend schemas |

**Design tokens.** Atlantic Blue `#004b87`, Sahara Sand `#e8c18c`, Moroccan Mint `#00a86b`;
Epilogue for headings, Manrope for body. Use `AppColors` and `AppTextStyles` — never a raw
`Color(0x…)` or a bare `TextStyle(` in `lib/screens/`.

**Error UX is three-tiered.** `InlineError` for a field, `ErrorState` for a screen (with retry),
SnackBar for **success only**. The invariant: *a SnackBar may never be the only report of a
failure.* Two pre-existing violations remain, both deliberately deferred:
`premium_modal_widget.dart:336` (payment failure) and `guide_dashboard_screen.dart:325` (route-save
failure).

`map_screen.dart` carries `flutter_map`, GPS, OSRM routing, polyline geometry and the route-save
payload, and has **no test coverage**. Treat cosmetic edits there as risky.

## Invariants — do not break these

- **Navigation:** no `MaterialPageRoute` anywhere outside `main.dart`. Currently holds, but
  nothing enforces it — no test asserts this. Check by hand:
  `grep -rn "MaterialPageRoute" lib/ | grep -v main.dart` must print nothing.
- **`require_admin` (`api/deps.py:62`) is the only admin authority.** It reads the `ADMIN_EMAILS`
  whitelist, ignores both the `is_admin` column and the `administrator` role, and fails closed on
  an empty list. Nobody can become an admin by writing to the database. `user.is_admin` is a
  display cache refreshed at login — **never read it for an access decision.**
- **Rating aggregates are denormalized.** `Guide.average_rating` and `total_reviews` are recomputed
  by `Guide.refresh_rating_stats()` (`models.py:117`) after each review insert/delete. Never write
  them by hand.
- **One active route per guide** is enforced procedurally: route creation deactivates the guide's
  prior routes before inserting (`services/route_service.py`).
- **Guide visibility.** Search filters `Guide.approval_status == "approved"` **and**
  `User.is_active` (`repositories/guide_repository.py:118-124`) — *not* `is_verified`, which is
  only the optional `verified_only` filter. A newly registered guide is invisible until an admin
  approves them, even after uploading documents.
- **Adding a DB column touches three places:** `app/models.py`, a new Alembic migration, **and**
  `docs/database_shemas.sql`. All three, every time.
- **PostGIS is required.** `CREATE EXTENSION IF NOT EXISTS postgis;` — `GuideRoute` will not work
  without it. New geometry columns go in both `models.py` (`Geometry(...)`) and
  `docs/database_shemas.sql` (`GEOMETRY(..., 4326)`).
- **Never `git add -A` or `git add .`.** The working tree routinely carries unrelated uncommitted
  changes. Always use explicit pathspecs: `git commit -m "..." -- <paths>`.
- **Public endpoints return `PublicGuideCard`, never `GuideResponse` or `UserResponse`.** Those two
  carry email, `is_admin` and the identity-document URLs, and exist for the admin and self
  audiences only. A flat projection that enumerates its fields is the pattern — copying an ORM row
  into a response schema is how the original breach happened.
- **Never widen the static mount past `/uploads/profiles`** (`main.py`). `licenses/` and `cines/`
  hold national identity cards; they are served only by the admin-guarded document endpoint.
- **Auth responses must not vary by account existence** — not in message text, not in status code,
  not in the `data` field. `resend_verification` and `forgot_password` return `None` precisely so
  that no caller has an outcome to branch on.
- **Every new auth-adjacent route gets `@limiter.limit(...)` and a `request: Request` parameter.**
  Omitting the parameter raises at startup; omitting the decorator silently leaves the route open.
- **Exception text never reaches a response body.** Log it, return a constant message. SQLAlchemy
  and pg8000 exceptions carry the database host, port, name and user.

## Security hardening — completed 2026-08-27

The audit's findings are **implemented**, on branch `security/backend-hardening`. Design and plan:

- `docs/superpowers/specs/2026-08-25-backend-security-hardening-design.md`
- `docs/superpowers/plans/2026-08-25-backend-security-hardening.md`

Root cause worth internalising, because it outlives the individual bugs: **response schemas were
keyed to what the ORM row holds rather than to who may read it.** `GuideResponse` and
`UserResponse` are field-by-field dumps of their tables, so any endpoint returning them publishes
whatever those tables gain next. That is how two unauthenticated endpoints came to serve every
guide's licence and CINE national identity card. The fix is an audience-keyed flat projection,
`PublicGuideCard` — it names its fields one by one, so a new column is invisible until someone
adds it deliberately.

What changed:

| Fixed | Where |
|---|---|
| Anonymous endpoints no longer emit PII or document URLs | `PublicGuideCard` in `schemas.py`; `api/search.py`, `api/guides.py` |
| Identity documents behind admin auth | `GET /api/v1/admin/guides/{id}/documents/{type}` |
| Static mount narrowed to profile photos | `main.py` mounts `/uploads/profiles` only |
| Guide phone behind login | `GET /api/v1/guides/{id}/contact` |
| Email verification links expire | `AuthService._consume_verification_token` — one shared path |
| Three enumeration oracles closed | `api/auth.py` returns constants; the service returns `None` |
| JWTs revocable, lifetime 30d → 7d | `tv` claim vs `users.token_version`; `auth.py`, `config.py` |
| Rate limiting on five auth routes | `app/rate_limit.py` + `@limiter.limit` decorators |
| Exception text no longer returned | `api/health.py`, `exceptions.py` log it instead |
| CORS restricted, `DEBUG` off, weak `SECRET_KEY` refused at startup | `main.py`, `config.py` |
| Password floor 6 → 10, complexity enforced | `auth.validate_password_strength`, wired into `schemas.py` |
| Uploads validated (extension, 5 MiB cap, magic bytes) | `uploads.py` |

Two latent crashes were found and fixed along the way: `is_token_expired` compared a naive
`utcnow()` against a `TIMESTAMPTZ` column (500 on any token loaded fresh from Postgres), and
`save_upload_file` called `relative_to(Path("."))` on an absolute path (`ValueError` after the file
was already written).

## Planning documents

- `docs/plans/00-overview.md` — the five-plan roadmap. Plans 01 (layering), 03 (tests) and 04
  (Docker/CI) are complete; 02 (frontend redesign) is complete through Phase 3; 05 (AWS) is not
  started.
- `docs/superpowers/specs/` and `docs/superpowers/plans/` — per-project designs and task plans.

## Environment

`backend/.env` holds `DATABASE_URL`, `SECRET_KEY`, `CORS_ORIGINS`, `ADMIN_EMAILS`. It is
**gitignored (`.gitignore:18`) and untracked** — no secret is in version control. A weak or
placeholder `SECRET_KEY` still lets anyone forge a token for any account, so use a long random
value; since the security work, `create_app()` refuses to start on a placeholder or on anything
shorter than 32 characters.

`CORS_ORIGINS` is now load-bearing rather than decorative: `main.py` passes
`settings.cors_origins_list` to the CORS middleware, so an origin missing from that variable is
refused. Access tokens last 7 days (`ACCESS_TOKEN_EXPIRE_MINUTES = 10080`) and are revocable by
incrementing `users.token_version`.

`docs/` is gitignored (`.gitignore:28`), so the specs, plans and roadmap are local-only and never
committed. This file is **not** ignored and is tracked normally.

`frontend/pubspec.lock` **is tracked**, and the `.gitignore` line meant to exclude it does not
work:

```
frontend/pubspec.lock  # Optionnel (certains préfèrent le garder)
```

Git treats `#` as a comment character **only at the start of a line**. Here the whole string
including the trailing text is the pattern, so it matches no file and the rule is inert. If you
ever intend to ignore the lockfile, the comment has to move to its own line — but tracking it is
the better default for reproducible builds, so leaving it as-is is fine.

Code comments, docstrings and user-facing strings in this project are **French**. Match the
surrounding language. Commit messages are English.
