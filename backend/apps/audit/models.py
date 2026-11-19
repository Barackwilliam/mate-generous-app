from django.conf import settings
from django.db import models


class AuditLog(models.Model):
    """An append-only record of sensitive actions: who did what, to whom, and when.

    Every manual financial or entitlement change made by staff must write one
    of these. Rows are never edited or deleted through the admin.
    """

    class Action(models.TextChoices):
        SUBSCRIPTION_MANUAL_GRANT = "subscription.manual_grant", "Subscription granted manually"
        SUBSCRIPTION_MANUAL_EXTEND = "subscription.manual_extend", "Subscription extended manually"
        SUBSCRIPTION_CANCEL = "subscription.cancel", "Subscription cancelled"
        PURCHASE_MANUAL_GRANT = "purchase.manual_grant", "Product granted manually"
        PURCHASE_REVOKE = "purchase.revoke", "Product revoked"
        TRANSACTION_MANUAL_CONFIRM = "transaction.manual_confirm", "Transaction confirmed manually"
        TRANSACTION_MANUAL_FAIL = "transaction.manual_fail", "Transaction marked failed manually"
        USER_DEACTIVATE = "user.deactivate", "User deactivated"
        USER_ACTIVATE = "user.activate", "User activated"

    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="audit_actions",
        help_text="Staff member who performed the action. Empty means the system did it.",
    )
    action = models.CharField(max_length=64, choices=Action.choices, db_index=True)
    target_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="audit_entries",
    )
    object_type = models.CharField(max_length=64, blank=True)
    object_id = models.CharField(max_length=64, blank=True)
    reason = models.TextField(blank=True)
    details = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        who = self.actor or "system"
        return f"{self.created_at:%Y-%m-%d %H:%M} {who} {self.action}"


def record(action, *, actor=None, target_user=None, obj=None, reason="", **details):
    return AuditLog.objects.create(
        actor=actor,
        action=action,
        target_user=target_user,
        object_type=obj._meta.label if obj is not None else "",
        object_id=str(obj.pk) if obj is not None else "",
        reason=reason,
        details=details,
    )
