from django.contrib import admin, messages
from django.db import models
from unfold.admin import ModelAdmin, TabularInline
from unfold.contrib.forms.widgets import WysiwygWidget

from .models import Author, Category, Content, HomeSection, PublishStatus, Series, Topic


class StatusActionsMixin:
    actions = ["publish", "archive"]

    @admin.action(description="Publish selected")
    def publish(self, request, queryset):
        n = queryset.update(status=PublishStatus.PUBLISHED)
        self.message_user(request, f"{n} published.", messages.SUCCESS)

    @admin.action(description="Archive selected")
    def archive(self, request, queryset):
        n = queryset.update(status=PublishStatus.ARCHIVED)
        self.message_user(request, f"{n} archived.", messages.SUCCESS)


@admin.register(Category)
class CategoryAdmin(StatusActionsMixin, ModelAdmin):
    list_display = ("name", "order", "status", "is_flagship")
    list_editable = ("order", "status")
    list_filter = ("status",)
    search_fields = ("name",)
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Series)
class SeriesAdmin(StatusActionsMixin, ModelAdmin):
    list_display = ("title", "category", "access_level", "price", "order", "status")
    list_editable = ("order", "status")
    list_filter = ("category", "status", "access_level")
    search_fields = ("title",)
    prepopulated_fields = {"slug": ("title",)}
    autocomplete_fields = ("category", "author")


@admin.register(Author)
class AuthorAdmin(ModelAdmin):
    search_fields = ("name",)
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Topic)
class TopicAdmin(ModelAdmin):
    search_fields = ("name",)
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Content)
class ContentAdmin(StatusActionsMixin, ModelAdmin):
    list_display = ("title", "category", "series", "kind", "access_level", "status", "publish_at", "is_featured")
    list_filter = ("status", "category", "kind", "access_level", "is_featured")
    search_fields = ("title", "scripture_reference", "body")
    date_hierarchy = "publish_at"
    prepopulated_fields = {"slug": ("title",)}
    autocomplete_fields = ("category", "series", "author", "topics")
    formfield_overrides = {models.TextField: {"widget": WysiwygWidget}}
    fieldsets = (
        (None, {"fields": ("title", "slug", "kind", "category", "series", "order_in_series", "author", "topics", "cover_image")}),
        ("Scripture", {"fields": ("scripture_reference", "scripture_text")}),
        ("Message", {"fields": ("summary", "body", "application", "prayer")}),
        ("Audio", {"fields": ("audio_file", "audio_url", "audio_duration_seconds")}),
        ("Access & sharing", {"fields": ("access_level", "price", "share_excerpt")}),
        ("Publishing", {"fields": ("status", "publish_at", "is_featured")}),
    )

    def formfield_for_dbfield(self, db_field, request, **kwargs):
        # Plain text boxes for short fields; rich text only where formatting matters.
        if db_field.name in {"scripture_text", "summary", "share_excerpt"}:
            return db_field.formfield(**kwargs)
        return super().formfield_for_dbfield(db_field, request, **kwargs)


@admin.register(HomeSection)
class HomeSectionAdmin(ModelAdmin):
    list_display = ("title", "kind", "category", "limit", "order", "is_active")
    list_editable = ("order", "is_active", "limit")
