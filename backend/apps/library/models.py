from django.conf import settings
from django.db import models


class SavedItem(models.Model):
    class Kind(models.TextChoices):
        BOOKMARK = "bookmark", "Bookmark"
        FAVOURITE = "favourite", "Favourite"

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="saved_items")
    content = models.ForeignKey("catalog.Content", on_delete=models.CASCADE, related_name="saved_by")
    kind = models.CharField(max_length=10, choices=Kind.choices)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [models.UniqueConstraint(fields=["user", "content", "kind"], name="unique_saved_item")]


class ReadingProgress(models.Model):
    """Reading history and 'Continue reading'. One row per user per item."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="progress")
    content = models.ForeignKey("catalog.Content", on_delete=models.CASCADE, related_name="progress")
    percent = models.PositiveSmallIntegerField(default=0)
    audio_position_seconds = models.PositiveIntegerField(default=0)
    completed = models.BooleanField(default=False)
    first_opened_at = models.DateTimeField(auto_now_add=True)
    last_opened_at = models.DateTimeField(auto_now=True, db_index=True)

    class Meta:
        ordering = ["-last_opened_at"]
        verbose_name_plural = "reading progress"
        constraints = [models.UniqueConstraint(fields=["user", "content"], name="unique_progress")]
