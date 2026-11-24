from django.contrib import admin, messages
from django.db import models
from django.template.response import TemplateResponse
from unfold.decorators import action
from unfold.admin import ModelAdmin, TabularInline
from unfold.contrib.forms.widgets import WysiwygWidget

from . import importer
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
    actions_list = ["import_json"]

    def has_import_json_permission(self, request, obj=None):
        return request.user.has_perm("catalog.add_content")

    @action(description="Pakia maudhui (JSON)", url_path="import-json/", permissions=["import_json"])
    def import_json(self, request):
        reports, dry_run = [], False
        if request.method == "POST":
            dry_run = bool(request.POST.get("dry_run"))
            replace = bool(request.POST.get("replace_samples"))
            for i, f in enumerate(request.FILES.getlist("files")):
                try:
                    text = f.read().decode("utf-8-sig")
                except UnicodeDecodeError:
                    report = importer.Report(errors=["Faili si maandishi ya UTF-8 (hifadhi kama .json)."])
                else:
                    report = importer.load_text(text, replace_samples=replace and i == 0, dry_run=dry_run)
                reports.append((f.name, report))
            ok = [r for _, r in reports if not r.errors]
            if ok and not dry_run:
                messages.success(request, f"Imefanikiwa: faili {len(ok)} kati ya {len(reports)}.")
        context = {**self.admin_site.each_context(request), "reports": reports, "dry_run": dry_run,
                   "title": "Pakia maudhui (JSON)", "opts": self.model._meta}
        return TemplateResponse(request, "admin/catalog/import_content.html", context)
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
