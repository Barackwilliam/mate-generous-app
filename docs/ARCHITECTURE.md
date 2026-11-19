# Architecture

## Principle: the app is a renderer, the backend decides

The client wants new categories, series and products added without rebuilding the software. So:

- **Categories** (`catalog.Category`) have a name, slug, icon, colour, order and status (draft / published / archived). One category is marked as the **flagship** (Kesha la Usiku), and its latest published message is *Tonight's Message*.
- **Series** group content in order, for example a book, a prophecy series or a sermon set. A series can carry an access level and can be sold as a whole.
- **Content** is one readable or listenable item: title, author, Scripture reference and text, summary, body (rich text with headings, quotes and images), practical application, prayer, audio, cover, topics, access level, optional standalone price, admin-approved share excerpt, status and a scheduled `publish_at`.
- **Home sections** (`catalog.HomeSection`) are rows the admin adds and reorders: Continue Reading, Latest, Recommended, Latest from a category, Popular Series, Audio. The app draws whatever `/api/home/` returns, in that order.

Archiving a category or series hides everything inside it from the app at once, without deleting anything.

## Access model

There are three access levels on content:

| Level | Who opens it |
| --- | --- |
| `free` | Everyone, including visitors who are not signed in |
| `subscriber` | Any current subscription (Monthly, Quarterly, 6 Months, Annual or Premium) |
| `premium` | Premium subscription only (for example the Sermon Library for pastors) |

An item's effective level is the stricter of its own level and its series' level.

Separately from subscriptions, a user can **own** a single item or a whole series (`subscriptions.Purchase`). Ownership never expires. When a subscription ends, the user drops back to free access and keeps the account and everything they bought, as the brief requires.

`apps/subscriptions/entitlements.py` is the only place that answers "may this user open this?". The reader, search, audio and the library all go through it.

**What a locked item returns:** the title, Scripture reference, summary and the admin's share excerpt, plus how to unlock it (subscribe, buy the item, or buy the series). The body, application, prayer and audio link are never sent for locked items.

**Audio** is fetched through `/api/contents/<slug>/audio/`, which checks access first and then redirects. In production, media should sit in a **private** bucket so that this redirect is a short-lived signed URL. Otherwise someone who has the file URL could share it.

## Subscription engine

- Plans have a code, name, tier (`standard` / `premium`), duration in days, a price in TZS, and an active flag. The five plans are seeded **switched off with price 0**, so the client sets real prices in the admin and then activates them.
- Free is not a plan. It is the state of having no current subscription.
- Activation date, expiry date, tier and renewal status (`free`, `active`, `expiring_soon`) are all calculated by the engine.
- Renewing the same tier while it is still active **extends** the subscription: the new one starts when the current one ends, so the user never loses paid days.
- Expiry needs no background job. A subscription is current only while `starts_at <= now < expires_at`.

> **To confirm with the client:** we read "Premium" as a higher tier that also unlocks premium-only resources (sermons, pastoral material). If they meant something else, for example a lifetime plan, the model handles it by changing the plan's tier or duration. No code change is needed.

## Audit trail

`audit.AuditLog` records who did what, to which user, when, and why. It is written for every:

- manual subscription grant, extension or cancellation (a reason is required in the admin form)
- manual product grant or revocation
- manual payment confirmation or failure
- user activation or deactivation

The admin cannot add, edit or delete audit rows. Subscriptions, purchases and transactions cannot be deleted from the admin either.

## Security

- JWT authentication (30-minute access token, 30-day rotating refresh token). Login works with email or phone number, and phone numbers are normalised to `2557XXXXXXXX`.
- Django password validators on registration and password change.
- Rate limits: auth 10/min, payment start 20/min, plus general limits for visitors and users.
- In production: HTTPS redirect, secure cookies and HSTS. Startup fails if `DJANGO_SECRET_KEY` is missing, or if the sandbox payment gateway is configured without an explicit staging flag.
- Payment callbacks must carry a valid signature, and the paid amount must match the expected amount.

## Phase Two hooks already in place

- The content `kind` field is ready for courses, quizzes and video when they are added.
- The gateway adapter means Phase Two extras (card payments, gift subscriptions) add new code without changing the existing flow.
- The Flutter app gives iOS from the same codebase.
