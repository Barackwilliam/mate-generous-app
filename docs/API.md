# API reference (Phase One)

Base URL: `/api/`. Send `Authorization: Bearer <access token>` once the user is signed in. Lists are paginated (`?page=`, 20 per page).

## Auth
| Method | Path | Notes |
| --- | --- | --- |
| POST | `auth/register/` | `email, phone?, full_name, password` → `{user, tokens}` |
| POST | `auth/login/` | `identifier` (email **or** phone), `password` → `{user, tokens}` |
| POST | `auth/token/refresh/` | `refresh` → new `access` (and rotated `refresh`) |
| GET/PATCH | `auth/me/` | profile (`full_name`, `phone`) |
| POST | `auth/me/password/` | `old_password, new_password` |

## Content
| Method | Path | Notes |
| --- | --- | --- |
| GET | `home/` | `tonight` (full reader payload), `sections[]` in admin order, `access` |
| GET | `categories/` | active categories in admin order |
| GET | `series/?category__slug=` | series with `item_count` |
| GET | `series/<slug>/contents/` | items in series order |
| GET | `contents/` | cards. Filters: `q`, `category`, `series`, `author`, `topic`, `kind`, `has_audio=1` |
| GET | `contents/<slug>/` | reader: `body`, `application`, `prayer`, `navigation.previous/next`, `share`, `user_state`; locked items get `preview` + `unlock` instead |
| GET | `contents/<slug>/audio/` | 302 to the audio after an access check, 403 if locked |
| GET | `share/<slug>/` | public data for the shared-link web page (excerpt only) |

`q` searches title, Scripture reference, summary, text, series, topic and author. Locked items still show in results with `is_locked: true` so users can see what a subscription opens; their text is never returned.

## My Library
| Method | Path | Notes |
| --- | --- | --- |
| GET | `library/` | `bookmarks, favourites, owned_items, owned_series, history` |
| PUT/DELETE | `library/<slug>/bookmark/` | save or remove |
| PUT/DELETE | `library/<slug>/favourite/` | save or remove |
| PUT | `library/<slug>/progress/` | `percent?, audio_position_seconds?, completed?` |

## Subscriptions & payments
| Method | Path | Notes |
| --- | --- | --- |
| GET | `subscriptions/plans/` | active plans with prices |
| GET | `subscriptions/me/` | `tier` (null = free), `expires_at`, `renewal_status`, `history` |
| POST | `payments/start/` | one of `plan_id` / `content_id` / `series_id`, plus `phone`, `network` (`mpesa`, `airtel`, `mixx`) |
| GET | `payments/<reference>/` | poll until `success` or `failed` (asks the gateway) |
| GET | `payments/mine/` | my transactions (receipts) |
| POST | `payments/callback/<gateway>/` | server-to-server only, signature required |
