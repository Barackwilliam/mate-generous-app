from datetime import timedelta

from django.utils import timezone

from apps.accounts.models import User
from apps.catalog.models import Category, Content, Series
from apps.subscriptions.models import Plan


def user(email="msomaji@example.com", **kw):
    kw.setdefault("full_name", "Msomaji")
    return User.objects.create_user(email=email, password="Imani-Thabiti-2026", **kw)


def category(slug="kesha-la-usiku", **kw):
    return Category.objects.get_or_create(slug=slug, defaults={"name": slug.title(), **kw})[0]


def content(title="Usiku wa Matumaini", **kw):
    kw.setdefault("category", category())
    kw.setdefault("status", "published")
    kw.setdefault("publish_at", timezone.now() - timedelta(hours=1))
    kw.setdefault("body", "<p>Kilio huweza kudumu usiku...</p>")
    kw.setdefault("prayer", "Bwana, nipe tumaini.")
    return Content.objects.create(title=title, **kw)


def series(title="Danieli", **kw):
    kw.setdefault("category", category("unabii"))
    return Series.objects.create(title=title, **kw)


def plan(code="monthly-test", tier="standard", days=30, price=5000):
    return Plan.objects.create(code=code, name=code, tier=tier, duration_days=days, price=price, is_active=True)
