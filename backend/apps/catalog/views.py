from django.conf import settings
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.library.models import ReadingProgress, SavedItem
from apps.subscriptions import entitlements

from .models import Category, Content, HomeSection, PublishStatus, Series, Topic
from .serializers import (
    CategorySerializer,
    ContentCardSerializer,
    ContentDetailSerializer,
    SeriesSerializer,
    TopicSerializer,
)

CONTENT_RELATED = ("category", "series", "author")


class EntitlementContextMixin:
    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx["entitlements"] = entitlements.for_user(self.request.user)
        return ctx


class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = CategorySerializer
    lookup_field = "slug"
    pagination_class = None
    queryset = Category.objects.filter(status=PublishStatus.PUBLISHED)


class TopicViewSet(viewsets.ReadOnlyModelViewSet):
    """Topics that have published content, most used first (search suggestions)."""

    serializer_class = TopicSerializer
    lookup_field = "slug"
    pagination_class = None

    def get_queryset(self):
        published = Content.objects.published()
        return (
            Topic.objects.filter(contents__in=published)
            .annotate(uses=Count("contents", distinct=True))
            .order_by("-uses", "name")[:20]
        )


class SeriesViewSet(EntitlementContextMixin, viewsets.ReadOnlyModelViewSet):
    serializer_class = SeriesSerializer
    lookup_field = "slug"
    filterset_fields = {"category__slug": ["exact"], "author__slug": ["exact"]}

    def get_queryset(self):
        now = timezone.now()
        return (
            Series.objects.filter(status=PublishStatus.PUBLISHED, category__status=PublishStatus.PUBLISHED)
            .select_related("category", "author")
            .annotate(item_count=Count(
                "contents",
                filter=Q(contents__status=PublishStatus.PUBLISHED, contents__publish_at__lte=now),
            ))
        )

    @action(detail=True)
    def contents(self, request, slug=None):
        series = self.get_object()
        qs = Content.objects.published().filter(series=series).select_related(*CONTENT_RELATED)
        qs = qs.order_by("order_in_series", "publish_at", "id")
        page = self.paginate_queryset(qs)
        data = ContentCardSerializer(page, many=True, context=self.get_serializer_context()).data
        return self.get_paginated_response(data)


def search_filter(qs, q):
    """Title, Scripture, keyword, series, topic and author, in one box."""
    q = (q or "").strip()
    if not q:
        return qs
    return qs.filter(
        Q(title__icontains=q)
        | Q(scripture_reference__icontains=q)
        | Q(summary__icontains=q)
        | Q(body__icontains=q)
        | Q(series__title__icontains=q)
        | Q(topics__name__icontains=q)
        | Q(author__name__icontains=q)
    ).distinct()


class ContentViewSet(EntitlementContextMixin, viewsets.ReadOnlyModelViewSet):
    """List/search content and open it in the reader.

    ?q= searches; ?category=, ?series=, ?author=, ?topic=, ?kind=, ?has_audio=1 filter.
    Locked items still appear (with is_locked) so users can see what a subscription opens.
    """

    lookup_field = "slug"

    def get_serializer_class(self):
        return ContentDetailSerializer if self.action == "retrieve" else ContentCardSerializer

    def get_queryset(self):
        qs = Content.objects.published().select_related(*CONTENT_RELATED)
        p = self.request.query_params
        for param, field in (("category", "category__slug"), ("series", "series__slug"),
                             ("author", "author__slug"), ("topic", "topics__slug"), ("kind", "kind")):
            if p.get(param):
                qs = qs.filter(**{field: p[param]})
        if p.get("has_audio") in {"1", "true"}:
            qs = qs.filter(Q(audio_file__gt="") | Q(audio_url__gt=""))
        return search_filter(qs, p.get("q"))

    def retrieve(self, request, *args, **kwargs):
        content = self.get_object()
        data = self.get_serializer(content).data
        if request.user.is_authenticated:
            saved = set(SavedItem.objects.filter(user=request.user, content=content).values_list("kind", flat=True))
            progress = ReadingProgress.objects.filter(user=request.user, content=content).first()
            data["user_state"] = {
                "is_bookmarked": SavedItem.Kind.BOOKMARK in saved,
                "is_favourite": SavedItem.Kind.FAVOURITE in saved,
                "percent": progress.percent if progress else 0,
                "audio_position_seconds": progress.audio_position_seconds if progress else 0,
            }
        return Response(data)

    @action(detail=True)
    def audio(self, request, slug=None):
        """Hand out the audio only after checking access. Uploaded audio sits in
        the private Supabase bucket, so the URL returned is signed and expires."""
        content = self.get_object()
        if not content.has_audio:
            return Response(status=404)
        if not entitlements.for_user(request.user).can_open(content):
            raise PermissionDenied("Fungua kwa usajili ili kusikiliza.")
        url = content.audio_file.url if content.audio_file else content.audio_url
        return Response({
            "url": request.build_absolute_uri(url),
            "expires_in": settings.SIGNED_URL_SECONDS if content.audio_file else None,
            "duration_seconds": content.audio_duration_seconds,
        })


class HomeView(APIView):
    """Tonight's Message plus the admin-configured sections, in the admin's order."""

    def get(self, request):
        ent = entitlements.for_user(request.user)
        ctx = {"request": request, "entitlements": ent}
        published = Content.objects.published().select_related(*CONTENT_RELATED)

        tonight = published.filter(category__is_flagship=True).first()
        sections = []
        for section in HomeSection.objects.filter(is_active=True).select_related("category"):
            items = self._section_items(section, published, request)
            if items is None:
                continue
            payload = {"title": section.title, "kind": section.kind}
            if section.kind == HomeSection.Kind.SERIES_LIST:
                payload["series"] = SeriesSerializer(items, many=True, context=ctx).data
                if not payload["series"]:
                    continue
            else:
                payload["items"] = ContentCardSerializer(items, many=True, context=ctx).data
                if not payload["items"]:
                    continue
            if section.category_id:
                payload["category"] = {"slug": section.category.slug, "name": section.category.name}
            sections.append(payload)

        return Response({
            "tonight": ContentDetailSerializer(tonight, context=ctx).data if tonight else None,
            "sections": sections,
            "access": {"tier": ent.tier, "expires_at": ent.expires_at, "renewal_status": ent.renewal_status},
        })

    def _section_items(self, section, published, request):
        kind, limit = section.kind, section.limit
        if kind == HomeSection.Kind.CONTINUE_READING:
            if not request.user.is_authenticated:
                return None
            ids = list(
                ReadingProgress.objects.filter(user=request.user, completed=False)
                .values_list("content_id", flat=True)[:limit]
            )
            by_id = {c.pk: c for c in published.filter(pk__in=ids)}
            return [by_id[i] for i in ids if i in by_id]
        if kind == HomeSection.Kind.LATEST:
            return published[:limit]
        if kind == HomeSection.Kind.FEATURED:
            return published.filter(is_featured=True)[:limit]
        if kind == HomeSection.Kind.CATEGORY:
            return published.filter(category=section.category)[:limit] if section.category_id else None
        if kind == HomeSection.Kind.AUDIO:
            return published.filter(Q(audio_file__gt="") | Q(audio_url__gt=""))[:limit]
        if kind == HomeSection.Kind.SERIES_LIST:
            return (
                Series.objects.filter(status=PublishStatus.PUBLISHED, category__status=PublishStatus.PUBLISHED)
                .select_related("category", "author")
                .annotate(readers=Count("contents__progress"))
                .order_by("-readers", "order")[:limit]
            )
        return None


class ShareLandingView(APIView):
    """Public data for the web page a shared link opens. Only the approved excerpt."""

    permission_classes = []

    def get(self, request, slug):
        content = get_object_or_404(Content.objects.published().select_related("category"), slug=slug)
        return Response({
            "title": content.title,
            "category": content.category.name,
            "scripture_reference": content.scripture_reference,
            "excerpt": content.share_excerpt or (content.summary if content.effective_access_level == "free" else ""),
            "app_link": f"mategenerous://content/{content.slug}",
        })

