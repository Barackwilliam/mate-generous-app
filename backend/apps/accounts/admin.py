from django.contrib import admin, messages
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from unfold.admin import ModelAdmin
from unfold.forms import AdminPasswordChangeForm, UserChangeForm, UserCreationForm

from apps.audit.models import AuditLog, record

from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin, ModelAdmin):
    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm
    ordering = ("-date_joined",)
    list_display = ("email", "full_name", "phone", "is_active", "is_staff", "date_joined")
    list_filter = ("is_active", "is_staff")
    search_fields = ("email", "full_name", "phone")
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Profile", {"fields": ("full_name", "phone")}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")}),
        ("Dates", {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = ((None, {"classes": ("wide",), "fields": ("email", "full_name", "phone", "password1", "password2")}),)
    actions = ["deactivate", "activate"]

    @admin.action(description="Deactivate selected users (audited)")
    def deactivate(self, request, queryset):
        for user in queryset.filter(is_active=True).exclude(pk=request.user.pk):
            user.is_active = False
            user.save(update_fields=["is_active"])
            record(AuditLog.Action.USER_DEACTIVATE, actor=request.user, target_user=user, obj=user)
        self.message_user(request, "Done.", messages.SUCCESS)

    @admin.action(description="Activate selected users (audited)")
    def activate(self, request, queryset):
        for user in queryset.filter(is_active=False):
            user.is_active = True
            user.save(update_fields=["is_active"])
            record(AuditLog.Action.USER_ACTIVATE, actor=request.user, target_user=user, obj=user)
        self.message_user(request, "Done.", messages.SUCCESS)
