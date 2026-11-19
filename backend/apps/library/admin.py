from django.contrib import admin
from unfold.admin import ModelAdmin

from .models import ReadingProgress, SavedItem


@admin.register(SavedItem)
class SavedItemAdmin(ModelAdmin):
    list_display = ("user", "content", "kind", "created_at")
    list_filter = ("kind",)


@admin.register(ReadingProgress)
class ReadingProgressAdmin(ModelAdmin):
    list_display = ("user", "content", "percent", "completed", "last_opened_at")
