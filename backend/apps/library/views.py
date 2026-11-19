from django.shortcuts import get_object_or_404
from rest_framework import permissions, serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.catalog.models import Content
from apps.catalog.serializers import ContentCardSerializer, SeriesSerializer
from apps.subscriptions import entitlements
from apps.subscriptions.models import Purchase

from .models import ReadingProgress, SavedItem


def _cards(request, contents):
    ctx = {"request": request, "entitlements": entitlements.for_user(request.user)}
    return ContentCardSerializer(contents, many=True, context=ctx).data


class LibraryView(APIView):
    """My Library: saved items, what I own, and what I have been reading."""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        visible = Content.objects.published().select_related("category", "series", "author")

        def saved(kind):
            ids = SavedItem.objects.filter(user=user, kind=kind).values_list("content_id", flat=True)
            return _cards(request, visible.filter(pk__in=ids))

        history = ReadingProgress.objects.filter(user=user).select_related("content")[:50]
        visible_ids = set(visible.filter(pk__in=[h.content_id for h in history]).values_list("pk", flat=True))
        history = [h for h in history if h.content_id in visible_ids]
        cards = {c["id"]: c for c in _cards(request, [h.content for h in history])}

        purchases = Purchase.objects.filter(user=user, revoked_at__isnull=True).select_related(
            "content", "series__category", "series__author"
        )
        ctx = {"request": request, "entitlements": entitlements.for_user(user)}
        return Response({
            "bookmarks": saved(SavedItem.Kind.BOOKMARK),
            "favourites": saved(SavedItem.Kind.FAVOURITE),
            "owned_items": _cards(request, [p.content for p in purchases if p.content_id]),
            "owned_series": SeriesSerializer([p.series for p in purchases if p.series_id], many=True, context=ctx).data,
            "history": [
                {"content": cards[h.content_id], "percent": h.percent, "completed": h.completed,
                 "last_opened_at": h.last_opened_at}
                for h in history
            ],
        })


class SavedItemView(APIView):
    """PUT to save, DELETE to remove. kind is 'bookmark' or 'favourite'."""

    permission_classes = [permissions.IsAuthenticated]

    def _content(self, slug):
        return get_object_or_404(Content.objects.published(), slug=slug)

    def put(self, request, slug, kind):
        if kind not in SavedItem.Kind.values:
            return Response(status=status.HTTP_404_NOT_FOUND)
        SavedItem.objects.get_or_create(user=request.user, content=self._content(slug), kind=kind)
        return Response(status=status.HTTP_204_NO_CONTENT)

    def delete(self, request, slug, kind):
        SavedItem.objects.filter(user=request.user, content__slug=slug, kind=kind).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ProgressSerializer(serializers.Serializer):
    percent = serializers.IntegerField(min_value=0, max_value=100, required=False)
    audio_position_seconds = serializers.IntegerField(min_value=0, required=False)
    completed = serializers.BooleanField(required=False)


class ProgressView(APIView):
    """The reader reports progress here; it feeds history and Continue Reading."""

    permission_classes = [permissions.IsAuthenticated]

    def put(self, request, slug):
        content = get_object_or_404(Content.objects.published(), slug=slug)
        data = ProgressSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        progress, _ = ReadingProgress.objects.get_or_create(user=request.user, content=content)
        for field, value in data.validated_data.items():
            setattr(progress, field, value)
        if progress.percent >= 100:
            progress.completed = True
        progress.save()
        return Response(status=status.HTTP_204_NO_CONTENT)
