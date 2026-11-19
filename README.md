# Mate Generous App

A Christian digital library with **Kesha la Usiku** as its flagship nightly devotional, plus Asubuhi ya Tumaini, Weary Souls, Marriage & Family, Unabii, the Sermon Library and more.

The admin creates, renames, reorders, publishes or archives categories, series and home-screen sections from the dashboard. Nothing is hard-coded in the app, so a new department never needs a new app release.

## Repository layout

| Folder | What it is | Status |
| --- | --- | --- |
| `backend/` | Django + REST API + admin dashboard | Phase One built, 37 tests passing |
| `mobile/` | Flutter Android app (iOS in Phase Two from the same code) | Next |
| `docs/` | Architecture, API and payment decisions | |

## Phase One scope (agreed)

| # | Item | Where |
| --- | --- | --- |
| 1 | UI/UX design: app and admin | `mobile/`, admin theme (Unfold) |
| 2 | App contents: home, reader, categories & series, My Library, bookmarks & favourites, dark mode, font size | API ready; app next |
| 3 | Secure backend & API | `backend/` |
| 4 | Admin dashboard: users, devotionals, categories, series, audio, subscriptions, publishing & archiving | `/admin/` |
| 5 | Registration & My Library: login, profile, saved content, reading history | `/api/auth/`, `/api/library/` |
| 6 | Devotional reader: Scripture, text, headings, images, prayer/application, next/previous | `/api/contents/<slug>/` |
| 7 | Subscription engine: Free, Monthly, Quarterly, 6 Months, Annual, Premium, expiry & entitlements | `apps/subscriptions` |
| 8 | Payments: M-Pesa, Airtel Money, Mixx by Yas, verification, records, activation | `apps/payments` (see `docs/PAYMENTS.md`) |

## Run the backend locally

```bash
cd backend
python3 -m venv ../.venv && . ../.venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

- Admin dashboard: http://localhost:8000/admin/
- API: http://localhost:8000/api/
- From the Android emulator, the API is at `http://10.0.2.2:8000/api/`.

Run the tests:

```bash
cd backend && DJANGO_DEBUG=1 python manage.py test
```

Payments use the **sandbox** gateway until the real one is chosen. Sandbox numbers ending in `0000` fail, and every other number succeeds.

## Deploy (staging)

`render.yaml` sets up a Render web service and a Postgres database, with sandbox payments switched on for testing. The Android test build will go out through Codemagic (`codemagic.yaml`, added together with the Flutter app).

More detail is in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`docs/API.md`](docs/API.md) and [`docs/PAYMENTS.md`](docs/PAYMENTS.md).
