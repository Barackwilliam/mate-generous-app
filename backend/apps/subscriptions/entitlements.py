"""The single place that answers "may this user open this content?".

Every API that returns content goes through here, so the rules cannot drift
between the reader, search and the library.
"""

from dataclasses import dataclass
from datetime import timedelta

from django.utils import timezone

from apps.catalog.models import AccessLevel

from .models import Plan, Purchase, Subscription

EXPIRING_SOON = timedelta(days=5)


@dataclass
class Entitlements:
    tier: str | None  # None, "standard" or "premium"
    expires_at: object
    content_ids: set
    series_ids: set
    is_staff: bool = False

    def can_open(self, content):
        if self.is_staff:
            return True
        level = content.effective_access_level
        if level == AccessLevel.FREE:
            return True
        if content.pk in self.content_ids or (content.series_id and content.series_id in self.series_ids):
            return True
        if level == AccessLevel.SUBSCRIBER:
            return self.tier is not None
        return self.tier == Plan.Tier.PREMIUM

    @property
    def renewal_status(self):
        if self.tier is None:
            return "free"
        if self.expires_at - timezone.now() <= EXPIRING_SOON:
            return "expiring_soon"
        return "active"


ANONYMOUS = Entitlements(tier=None, expires_at=None, content_ids=set(), series_ids=set())


def for_user(user):
    if not user or not user.is_authenticated:
        return ANONYMOUS
    current = list(Subscription.objects.current().filter(user=user).order_by("-expires_at"))
    tier, expires_at = None, None
    if current:
        premium = [s for s in current if s.tier == Plan.Tier.PREMIUM]
        best = premium or current
        tier = best[0].tier
        # The furthest-out expiry among back-to-back subscriptions of that tier.
        expires_at = max(s.expires_at for s in Subscription.objects.filter(
            user=user, tier=tier, status=Subscription.Status.ACTIVE, expires_at__gt=timezone.now()
        ))
    owned = Purchase.objects.filter(user=user, revoked_at__isnull=True).values_list("content_id", "series_id")
    return Entitlements(
        tier=tier,
        expires_at=expires_at,
        content_ids={c for c, _ in owned if c},
        series_ids={s for _, s in owned if s},
        is_staff=user.is_staff,
    )
