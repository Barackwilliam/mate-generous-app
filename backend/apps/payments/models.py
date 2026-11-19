import secrets

from django.conf import settings
from django.db import models
from django.db.models import Q


def new_reference():
    return "MG" + secrets.token_hex(6).upper()


class Transaction(models.Model):
    class Network(models.TextChoices):
        MPESA = "mpesa", "M-Pesa"
        AIRTEL = "airtel", "Airtel Money"
        MIXX = "mixx", "Mixx by Yas"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        SUCCESS = "success", "Successful"
        FAILED = "failed", "Failed"

    class Kind(models.TextChoices):
        SUBSCRIPTION = "subscription", "Subscription"
        PRODUCT = "product", "Standalone product"

    reference = models.CharField(max_length=20, unique=True, default=new_reference, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="transactions")
    kind = models.CharField(max_length=12, choices=Kind.choices)
    plan = models.ForeignKey("subscriptions.Plan", null=True, blank=True, on_delete=models.PROTECT)
    content = models.ForeignKey("catalog.Content", null=True, blank=True, on_delete=models.PROTECT)
    series = models.ForeignKey("catalog.Series", null=True, blank=True, on_delete=models.PROTECT)
    amount = models.DecimalField(max_digits=10, decimal_places=0)
    currency = models.CharField(max_length=3, default="TZS")
    phone = models.CharField(max_length=15)
    network = models.CharField(max_length=10, choices=Network.choices)

    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING, db_index=True)
    gateway = models.CharField(max_length=30)
    gateway_reference = models.CharField(max_length=100, blank=True, db_index=True)
    failure_reason = models.CharField(max_length=255, blank=True)
    gateway_payload = models.JSONField(default=list, blank=True, help_text="Raw gateway messages, for disputes.")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.CheckConstraint(
                condition=(
                    Q(kind="subscription", plan__isnull=False, content__isnull=True, series__isnull=True)
                    | Q(kind="product", plan__isnull=True, content__isnull=False, series__isnull=True)
                    | Q(kind="product", plan__isnull=True, content__isnull=True, series__isnull=False)
                ),
                name="transaction_matches_kind",
            ),
        ]

    def __str__(self):
        return f"{self.reference} · {self.amount:,.0f} {self.currency} · {self.get_status_display()}"

    @property
    def item_name(self):
        return str(self.plan or self.content or self.series)

    def log(self, event, data):
        self.gateway_payload = [*self.gateway_payload, {"event": event, "data": data}]
