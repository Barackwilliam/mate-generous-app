from django import forms
from django.contrib import admin, messages
from django.core.exceptions import ValidationError
from django.utils import timezone
from unfold.admin import ModelAdmin

from apps.audit.models import AuditLog, record

from .models import Plan, Purchase, Subscription, next_start_for


@admin.register(Plan)
class PlanAdmin(ModelAdmin):
    list_display = ("name", "code", "tier", "duration_days", "price", "is_active", "order")
    list_editable = ("price", "is_active", "order")


class ManualGrantForm(forms.ModelForm):
    def clean(self):
        data = super().clean()
        if not (data.get("note") or "").strip():
            raise ValidationError("Write the reason for this manual change. It goes into the audit log.")
        return data


@admin.register(Subscription)
class SubscriptionAdmin(ModelAdmin):
    """Staff can grant or extend by hand; each change is audited. Nothing is deleted."""

    form = ManualGrantForm
    list_display = ("user", "plan", "starts_at", "expires_at", "status", "source", "is_current")
    list_filter = ("status", "source", "tier", "plan")
    search_fields = ("user__email", "user__phone")
    autocomplete_fields = ("user",)
    actions = ["cancel"]

    def get_fields(self, request, obj=None):
        if obj is None:
            return ("user", "plan", "starts_at", "note")
        return ("user", "plan", "starts_at", "expires_at", "status", "source", "transaction", "note")

    def get_readonly_fields(self, request, obj=None):
        return ("user", "plan", "starts_at", "source", "transaction", "status") if obj else ()

    def get_changeform_initial_data(self, request):
        return {"starts_at": timezone.now()}

    @admin.display(boolean=True)
    def is_current(self, obj):
        return obj.is_current

    def save_model(self, request, obj, form, change):
        if not change:
            obj.source = Subscription.Source.MANUAL
            obj.starts_at = max(obj.starts_at, next_start_for(obj.user, obj.plan))
            obj.expires_at = obj.starts_at + timezone.timedelta(days=obj.plan.duration_days)
            super().save_model(request, obj, form, change)
            record(AuditLog.Action.SUBSCRIPTION_MANUAL_GRANT, actor=request.user, target_user=obj.user,
                   obj=obj, reason=obj.note, plan=obj.plan.code, expires_at=obj.expires_at.isoformat())
            return
        before = Subscription.objects.get(pk=obj.pk).expires_at
        super().save_model(request, obj, form, change)
        if before != obj.expires_at:
            record(AuditLog.Action.SUBSCRIPTION_MANUAL_EXTEND, actor=request.user, target_user=obj.user,
                   obj=obj, reason=obj.note, before=before.isoformat(), after=obj.expires_at.isoformat())

    @admin.action(description="Cancel selected subscriptions (audited)")
    def cancel(self, request, queryset):
        for sub in queryset.filter(status=Subscription.Status.ACTIVE):
            sub.status = Subscription.Status.CANCELLED
            sub.save(update_fields=["status"])
            record(AuditLog.Action.SUBSCRIPTION_CANCEL, actor=request.user, target_user=sub.user,
                   obj=sub, reason="Cancelled from admin")
        self.message_user(request, "Cancelled and recorded in the audit log.", messages.SUCCESS)

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Purchase)
class PurchaseAdmin(ModelAdmin):
    form = ManualGrantForm
    list_display = ("user", "content", "series", "amount", "source", "created_at", "revoked_at")
    list_filter = ("source",)
    search_fields = ("user__email", "user__phone", "content__title", "series__title")
    autocomplete_fields = ("user", "content", "series")
    actions = ["revoke"]

    def get_fields(self, request, obj=None):
        return ("user", "content", "series", "note") if obj is None else (
            "user", "content", "series", "amount", "source", "transaction", "note", "revoked_at", "created_at")

    def get_readonly_fields(self, request, obj=None):
        return ("user", "content", "series", "amount", "source", "transaction", "revoked_at", "created_at") if obj else ()

    def save_model(self, request, obj, form, change):
        if not change:
            obj.source = Purchase.Source.MANUAL
            obj.amount = 0
        super().save_model(request, obj, form, change)
        if not change:
            record(AuditLog.Action.PURCHASE_MANUAL_GRANT, actor=request.user, target_user=obj.user,
                   obj=obj, reason=obj.note, product=str(obj.content or obj.series))

    @admin.action(description="Revoke selected products (audited)")
    def revoke(self, request, queryset):
        for p in queryset.filter(revoked_at__isnull=True):
            p.revoked_at = timezone.now()
            p.save(update_fields=["revoked_at"])
            record(AuditLog.Action.PURCHASE_REVOKE, actor=request.user, target_user=p.user, obj=p,
                   reason="Revoked from admin")
        self.message_user(request, "Revoked and recorded in the audit log.", messages.SUCCESS)

    def has_delete_permission(self, request, obj=None):
        return False
