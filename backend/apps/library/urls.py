from django.urls import path

from . import views

urlpatterns = [
    path("", views.LibraryView.as_view(), name="library"),
    path("<slug:slug>/progress/", views.ProgressView.as_view(), name="progress"),
    path("<slug:slug>/<str:kind>/", views.SavedItemView.as_view(), name="saved-item"),
]
