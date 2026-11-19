from django.conf import settings
from rest_framework import serializers

from .models import Author, Category, Content, Series


def _media_url(request, field):
    if not field:
        return None
    url = field.url
    return request.build_absolute_uri(url) if request else url


class CategorySerializer(serializers.ModelSerializer):
    cover_image = serializers.SerializerMethodField()

    class Meta:
        model = Category
        fields = ("id", "name", "slug", "description", "icon", "accent_color", "cover_image", "is_flagship", "order")

    def get_cover_image(self, obj):
        return _media_url(self.context.get("request"), obj.cover_image)


class CategoryRefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ("id", "name", "slug")


class AuthorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Author
        fields = ("id", "name", "slug", "title")


class SeriesSerializer(serializers.ModelSerializer):
    category = CategoryRefSerializer()
    author = AuthorSerializer()
    cover_image = serializers.SerializerMethodField()
    item_count = serializers.IntegerField(read_only=True, default=None)
    is_owned = serializers.SerializerMethodField()

    class Meta:
        model = Series
        fields = ("id", "title", "slug", "description", "category", "author", "cover_image",
                  "access_level", "price", "item_count", "is_owned")

    def get_cover_image(self, obj):
        return _media_url(self.context.get("request"), obj.cover_image)

    def get_is_owned(self, obj):
        ent = self.context.get("entitlements")
        return bool(ent and obj.pk in ent.series_ids)


class SeriesRefSerializer(serializers.ModelSerializer):
    class Meta:
        model = Series
        fields = ("id", "title", "slug")


class ContentCardSerializer(serializers.ModelSerializer):
    """What lists, the home screen and search return. Never contains the full text."""

    category = CategoryRefSerializer()
    series = SeriesRefSerializer()
    author = AuthorSerializer()
    cover_image = serializers.SerializerMethodField()
    access_level = serializers.CharField(source="effective_access_level")
    has_audio = serializers.BooleanField()
    is_locked = serializers.SerializerMethodField()

    class Meta:
        model = Content
        fields = ("id", "slug", "kind", "title", "category", "series", "author", "cover_image",
                  "scripture_reference", "summary", "has_audio", "audio_duration_seconds",
                  "access_level", "price", "is_locked", "publish_at")

    def get_cover_image(self, obj):
        return _media_url(self.context.get("request"), obj.cover_image)

    def get_is_locked(self, obj):
        ent = self.context.get("entitlements")
        return not (ent and ent.can_open(obj))


def _ref(item):
    return {"slug": item.slug, "title": item.title} if item else None


class ContentDetailSerializer(ContentCardSerializer):
    """The reader. Locked items get a preview and the ways to unlock, not the text."""

    scripture_text = serializers.CharField()
    body = serializers.SerializerMethodField()
    application = serializers.SerializerMethodField()
    prayer = serializers.SerializerMethodField()
    preview = serializers.SerializerMethodField()
    audio_stream_path = serializers.SerializerMethodField()
    navigation = serializers.SerializerMethodField()
    share = serializers.SerializerMethodField()
    unlock = serializers.SerializerMethodField()

    class Meta(ContentCardSerializer.Meta):
        fields = ContentCardSerializer.Meta.fields + (
            "scripture_text", "body", "application", "prayer", "preview",
            "audio_stream_path", "navigation", "share", "unlock",
        )

    def _open(self, obj):
        return not self.get_is_locked(obj)

    def get_body(self, obj):
        return obj.body if self._open(obj) else None

    def get_application(self, obj):
        return obj.application if self._open(obj) else None

    def get_prayer(self, obj):
        return obj.prayer if self._open(obj) else None

    def get_preview(self, obj):
        return None if self._open(obj) else (obj.share_excerpt or obj.summary)

    def get_audio_stream_path(self, obj):
        if obj.has_audio and self._open(obj):
            return f"/api/contents/{obj.slug}/audio/"
        return None

    def get_navigation(self, obj):
        return {"previous": _ref(obj.previous_item()), "next": _ref(obj.next_item())}

    def get_share(self, obj):
        excerpt = obj.share_excerpt or (obj.summary if obj.effective_access_level == "free" else "")
        return {
            "excerpt": excerpt,
            "url": f"{settings.SHARE_BASE_URL.rstrip('/')}/m/{obj.slug}",
            "scripture_reference": obj.scripture_reference,
        }

    def get_unlock(self, obj):
        if self._open(obj):
            return None
        options = {"subscribe": True, "tier": "premium" if obj.effective_access_level == "premium" else "standard"}
        if obj.price:
            options["buy_item"] = {"content_id": obj.pk, "price": obj.price}
        if obj.series_id and obj.series.price:
            options["buy_series"] = {"series_id": obj.series_id, "price": obj.series.price}
        return options
