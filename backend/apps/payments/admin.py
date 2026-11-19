from django.contrib import admin, messages
from unfold.admin import ModelAdmin

from .gateways import GatewayResult
from .models import Transaction
from .services import apply_result, refresh_status


@admin.register(Transaction)
class TransactionAdmin(ModelAdmin):
    list_display = ("reference", "user", "kind", "amount", "network", "phone", "status", "created_at")
    list_filter = ("status", "network", "kind", "gateway")
    search_fields = ("reference", "gateway_reference", "user__email", "phone")
    date_hierarchy = "created_at"
    readonly_fields = [f.name for f in Transaction._meta.fields]
    actions = ["check_with_gateway", "confirm_manually", "mark_failed"]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return request.method in {"GET", "HEAD"} or obj is None

    def has_delete_permission(self, request, obj=None):
        return False

    @admin.action(description="Check status with the gateway")
    def check_with_gateway(self, request, queryset):
        for txn in queryset.filter(status=Transaction.Status.PENDING):
            refresh_status(txn)
        self.message_user(request, "Checked.", messages.SUCCESS)

    @admin.action(description="Confirm payment manually (exceptional — audited)")
    def confirm_manually(self, request, queryset):
        for txn in queryset.filter(status=Transaction.Status.PENDING):
            apply_result(txn.pk, GatewayResult(status="success", message="Confirmed by staff"),
                         source="manual", actor=request.user, reason="Confirmed manually from admin")
        self.message_user(request, "Confirmed, access activated, and recorded in the audit log.", messages.WARNING)

    @admin.action(description="Mark as failed (audited)")
    def mark_failed(self, request, queryset):
        for txn in queryset.filter(status=Transaction.Status.PENDING):
            apply_result(txn.pk, GatewayResult(status="failed", message="Marked failed by staff"),
                         source="manual", actor=request.user, reason="Marked failed from admin")
        self.message_user(request, "Marked failed and recorded in the audit log.", messages.SUCCESS)
