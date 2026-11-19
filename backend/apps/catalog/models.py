"""The content library.

Nothing here is hard-coded into the app: categories, series, home-screen
sections and content are all rows an administrator creates, renames, reorders,
publishes or archives from the dashboard. The Android app only renders what the
API returns, so new departments never need a new app release.
"""

from django.db import models
from django.db.models import Q
from django.utils import timezone
from django.utils.text import slugify


class PublishStatus(models.TextChoices):
    DRAFT = "draft", "Draft"
    PUBLISHED = "published", "Published"
    ARCHIVED = "archived", "Archived"


class AccessLevel(models.TextChoices):
    FREE = "free", "Free for everyone"
    SUBSCRIBER = "subscriber", "Any active subscription"
    PREMIUM = "premium", "Premium subscription only"


class SlugMixin(models.Model):
    slug_source = "title"

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        if not self.slug:
            base = slugify(getattr(self, self.slug_source))[:200] or "item"
            slug, n = base, 2
            while type(self).objects.filter(slug=slug).exclude(pk=self.pk).exists():
                slug, n = f"{base}-{n}", n + 1
            self.slug = slug
        super().save(*args, **kwargs)


class Category(SlugMixin, models.Model):
    slug_source = "name"

    name = models.CharField(max_length=120)
    slug = models.SlugField(max_length=200, unique=True, blank=True)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=60, blank=True, help_text="Material icon name, e.g. nights_stay")
    cover_image = models.ImageField(upload_to="categories/", blank=True)
    accent_color = models.CharField(max_length=7, blank=True, help_text="Hex colour, e.g. #1F3A5F")
    is_flagship = models.BooleanField(
        default=False,
        help_text="The flagship publication (Kesha la Usiku). Its latest message is Tonight's Message.",
    )
    order = models.PositiveIntegerField(default=0, db_index=True)
    status = models.CharField(max_length=10, choices=PublishStatus.choices, default=PublishStatus.PUBLISHED)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "name"]
        verbose_name_plural = "categories"
        constraints = [
            models.UniqueConstraint(fields=["is_flagship"], condition=Q(is_flagship=True), name="one_flagship_category"),
        ]

    def __str__(self):
        return self.name


class Author(SlugMixin, models.Model):
    slug_source = "name"

    name = models.CharField(max_length=150)
    slug = models.SlugField(max_length=200, unique=True, blank=True)
    title = models.CharField(max_length=150, blank=True, help_text="e.g. Pastor, Elder")
    bio = models.TextField(blank=True)
    photo = models.ImageField(upload_to="authors/", blank=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Topic(SlugMixin, models.Model):
    slug_source = "name"

    name = models.CharField(max_length=80, unique=True)
    slug = models.SlugField(max_length=200, unique=True, blank=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class Series(SlugMixin, models.Model):
    category = models.ForeignKey(Category, on_delete=models.PROTECT, related_name="series")
    title = models.CharField(max_length=200)
    slug = models.SlugField(max_length=200, unique=True, blank=True)
    description = models.TextField(blank=True)
    cover_image = models.ImageField(upload_to="series/", blank=True)
    author = models.ForeignKey(Author, null=True, blank=True, on_delete=models.SET_NULL, related_name="series")
    access_level = models.CharField(
        max_length=12,
        choices=AccessLevel.choices,
        default=AccessLevel.FREE,
        help_text="Minimum access for every item in the series. An item can still require more.",
    )
    price = models.DecimalField(
        max_digits=10,
        decimal_places=0,
        null=True,
        blank=True,
        help_text="Set a TZS price to sell the whole series (e.g. a book) on its own. Leave empty if not for sale.",
    )
    order = models.PositiveIntegerField(default=0, db_index=True)
    status = models.CharField(max_length=10, choices=PublishStatus.choices, default=PublishStatus.PUBLISHED)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "title"]
        verbose_name_plural = "series"

    def __str__(self):
        return self.title


class ContentQuerySet(models.QuerySet):
    def published(self):
        """Visible to app users: published, release time reached, and nothing it sits in is archived."""
        return self.filter(
            status=PublishStatus.PUBLISHED,
            publish_at__lte=timezone.now(),
            category__status=PublishStatus.PUBLISHED,
        ).filter(Q(series__isnull=True) | Q(series__status=PublishStatus.PUBLISHED))


class Content(SlugMixin, models.Model):
    class Kind(models.TextChoices):
        DEVOTIONAL = "devotional", "Devotional"
        ARTICLE = "article", "Article / study"
        SERMON = "sermon", "Sermon"
        AUDIO = "audio", "Audio only"
        BOOK_CHAPTER = "book_chapter", "Book chapter"

    kind = models.CharField(max_length=20, choices=Kind.choices, default=Kind.DEVOTIONAL)
    title = models.CharField(max_length=200)
    slug = models.SlugField(max_length=200, unique=True, blank=True)
    category = models.ForeignKey(Category, on_delete=models.PROTECT, related_name="contents")
    series = models.ForeignKey(Series, null=True, blank=True, on_delete=models.SET_NULL, related_name="contents")
    order_in_series = models.PositiveIntegerField(default=0)
    author = models.ForeignKey(Author, null=True, blank=True, on_delete=models.SET_NULL, related_name="contents")
    topics = models.ManyToManyField(Topic, blank=True, related_name="contents")
    cover_image = models.ImageField(upload_to="content/", blank=True)

    scripture_reference = models.CharField(max_length=120, blank=True, help_text="e.g. Zaburi 30:5")
    scripture_text = models.TextField(blank=True)
    summary = models.TextField(blank=True, help_text="One or two lines shown on cards and in search.")
    body = models.TextField(blank=True, help_text="Main devotional text. Headings, quotes and images allowed.")
    application = models.TextField(blank=True, help_text="Practical application.")
    prayer = models.TextField(blank=True)

    audio_file = models.FileField(upload_to="audio/", blank=True)
    audio_url = models.URLField(blank=True, help_text="Use instead of uploading if the audio is hosted elsewhere.")
    audio_duration_seconds = models.PositiveIntegerField(null=True, blank=True)

    access_level = models.CharField(max_length=12, choices=AccessLevel.choices, default=AccessLevel.FREE)
    price = models.DecimalField(
        max_digits=10,
        decimal_places=0,
        null=True,
        blank=True,
        help_text="Set a TZS price to sell this item on its own. Leave empty if not for sale.",
    )
    share_excerpt = models.TextField(
        blank=True,
        help_text="The only text users may share. Premium items are never shared in full.",
    )

    status = models.CharField(max_length=10, choices=PublishStatus.choices, default=PublishStatus.DRAFT)
    publish_at = models.DateTimeField(default=timezone.now, db_index=True, help_text="Set a future time to schedule.")
    is_featured = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = ContentQuerySet.as_manager()

    class Meta:
        ordering = ["-publish_at"]
        indexes = [models.Index(fields=["status", "publish_at"])]

    def __str__(self):
        return self.title

    @property
    def effective_access_level(self):
        """The stricter of the item's own level and its series' level."""
        rank = {AccessLevel.FREE: 0, AccessLevel.SUBSCRIBER: 1, AccessLevel.PREMIUM: 2}
        own = self.access_level
        series_level = self.series.access_level if self.series_id else AccessLevel.FREE
        return own if rank[own] >= rank[series_level] else series_level

    @property
    def has_audio(self):
        return bool(self.audio_file or self.audio_url)

    def _neighbour(self, direction):
        """Next/previous item in reading order: within the series, otherwise within the category."""
        qs = Content.objects.published().exclude(pk=self.pk)
        if self.series_id:
            qs = qs.filter(series_id=self.series_id)
            keys = ["order_in_series", "publish_at", "id"]
        else:
            qs = qs.filter(category_id=self.category_id, series__isnull=True)
            keys = ["publish_at", "id"]

        op = "gt" if direction == "next" else "lt"
        condition = Q()
        for i, key in enumerate(keys):
            step = Q(**{f"{key}__{op}": getattr(self, key)})
            for earlier in keys[:i]:
                step &= Q(**{earlier: getattr(self, earlier)})
            condition |= step
        ordering = keys if direction == "next" else [f"-{k}" for k in keys]
        return qs.filter(condition).order_by(*ordering).first()

    def next_item(self):
        return self._neighbour("next")

    def previous_item(self):
        return self._neighbour("previous")


class HomeSection(models.Model):
    """One row on the home screen. Admins add, reorder and switch these off freely."""

    class Kind(models.TextChoices):
        CONTINUE_READING = "continue_reading", "Continue reading (signed-in users)"
        LATEST = "latest", "Latest messages"
        FEATURED = "featured", "Recommended / featured"
        CATEGORY = "category", "Latest from one category"
        SERIES_LIST = "series_list", "Popular series"
        AUDIO = "audio", "Latest audio"

    title = models.CharField(max_length=120)
    kind = models.CharField(max_length=20, choices=Kind.choices)
    category = models.ForeignKey(
        Category, null=True, blank=True, on_delete=models.CASCADE, help_text="Only for 'Latest from one category'."
    )
    limit = models.PositiveSmallIntegerField(default=10)
    order = models.PositiveIntegerField(default=0, db_index=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["order", "id"]

    def __str__(self):
        return self.title
