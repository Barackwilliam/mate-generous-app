from datetime import timedelta

from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone


class Plan(models.Model):
    """A subscription product. Free access needs no plan: it is what a user has without one."""

    class Tier(models.TextChoices):
        STANDARD = "standard", "Standard"
        PREMIUM = "premium", "Premium"

    code = models.SlugField(max_length=40, unique=True)
    name = models.CharField(max_length=80)
    description = models.TextField(blank=True)
    tier = models.CharField(
        max_length=10,
        choices=Tier.choices,
        default=Tier.STANDARD,
        help_text="Premium unlocks premium content (e.g. the Sermon Library) as well as standard content.",
    )
    duration_days = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=0, help_text="TZS")
    is_active = models.BooleanField(default=True, help_text="Only active plans can be bought.")
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["order", "duration_days"]

    def __str__(self):
        return f"{self.name} ({self.price:,.0f} TZS)"


class SubscriptionQuerySet(models.QuerySet):
    def current(self, at=None):
        at = at or timezone.now()
        return self.filter(status=Subscription.Status.ACTIVE, starts_at__lte=at, expires_at__gt=at)


class Subscription(models.Model):
    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        CANCELLED = "cancelled", "Cancelled"

    class Source(models.TextChoices):
        PAYMENT = "payment", "Payment"
        MANUAL = "manual", "Manual (admin)"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="subscriptions")
    plan = models.ForeignKey(Plan, on_delete=models.PROTECT, related_name="subscriptions")
    tier = models.CharField(max_length=10, choices=Plan.Tier.choices, editable=False)
    starts_at = models.DateTimeField()
    expires_at = models.DateTimeField(db_index=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.ACTIVE)
    source = models.CharField(max_length=10, choices=Source.choices, default=Source.PAYMENT)
    transaction = models.OneToOneField(
        "payments.Transaction", null=True, blank=True, on_delete=models.PROTECT, related_name="subscription"
    )
    note = models.TextField(blank=True, help_text="Required reason when granted manually.")
    created_at = models.DateTimeField(auto_now_add=True)

    objects = SubscriptionQuerySet.as_manager()

    class Meta:
        ordering = ["-expires_at"]

    def save(self, *args, **kwargs):
        self.tier = self.plan.tier
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.user} · {self.plan.name} → {self.expires_at:%Y-%m-%d}"

    @property
    def is_current(self):
        now = timezone.now()
        return self.status == self.Status.ACTIVE and self.starts_at <= now < self.expires_at


class Purchase(models.Model):
    """A standalone product (one item or a whole series) the user owns for good.

    Kept apart from subscriptions so it survives a subscription expiring.
    """

    class Source(models.TextChoices):
        PAYMENT = "payment", "Payment"
        MANUAL = "manual", "Manual (admin)"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="purchases")
    content = models.ForeignKey(
        "catalog.Content", null=True, blank=True, on_delete=models.PROTECT, related_name="purchases"
    )
    series = models.ForeignKey(
        "catalog.Series", null=True, blank=True, on_delete=models.PROTECT, related_name="purchases"
    )
    amount = models.DecimalField(max_digits=10, decimal_places=0, default=0)
    source = models.CharField(max_length=10, choices=Source.choices, default=Source.PAYMENT)
    transaction = models.OneToOneField(
        "payments.Transaction", null=True, blank=True, on_delete=models.PROTECT, related_name="purchase"
    )
    note = models.TextField(blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.CheckConstraint(
                condition=(Q(content__isnull=False) & Q(series__isnull=True))
                | (Q(content__isnull=True) & Q(series__isnull=False)),
                name="purchase_exactly_one_product",
            ),
        ]

    def __str__(self):
        return f"{self.user} · {self.content or self.series}"


def next_start_for(user, plan, now=None):
    """Buying the same tier again while still active extends it instead of overlapping."""
    now = now or timezone.now()
    latest = (
        Subscription.objects.filter(user=user, tier=plan.tier, status=Subscription.Status.ACTIVE, expires_at__gt=now)
        .order_by("-expires_at")
        .values_list("expires_at", flat=True)
        .first()
    )
    return max(now, latest) if latest else now


def create_subscription(user, plan, *, source, transaction=None, note="", now=None):
    starts_at = next_start_for(user, plan, now)
    return Subscription.objects.create(
        user=user,
        plan=plan,
        starts_at=starts_at,
        expires_at=starts_at + timedelta(days=plan.duration_days),
        source=source,
        transaction=transaction,
        note=note,
    )
