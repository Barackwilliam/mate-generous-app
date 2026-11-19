from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path
from rest_framework.routers import DefaultRouter

from apps.catalog import views as catalog

router = DefaultRouter()
router.register("categories", catalog.CategoryViewSet, basename="category")
router.register("series", catalog.SeriesViewSet, basename="series")
router.register("contents", catalog.ContentViewSet, basename="content")

urlpatterns = [
    path("admin/", admin.site.urls),
    path("health/", lambda request: JsonResponse({"ok": True})),
    path("api/home/", catalog.HomeView.as_view(), name="home"),
    path("api/share/<slug:slug>/", catalog.ShareLandingView.as_view(), name="share"),
    path("api/auth/", include("apps.accounts.urls")),
    path("api/library/", include("apps.library.urls")),
    path("api/subscriptions/", include("apps.subscriptions.urls")),
    path("api/payments/", include("apps.payments.urls")),
    path("api/", include(router.urls)),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
