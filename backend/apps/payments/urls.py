from django.urls import path

from . import views

urlpatterns = [
    path("start/", views.StartPaymentView.as_view(), name="payment-start"),
    path("mine/", views.MyTransactionsView.as_view(), name="my-transactions"),
    path("callback/<str:gateway>/", views.GatewayCallbackView.as_view(), name="payment-callback"),
    path("<str:reference>/", views.TransactionStatusView.as_view(), name="payment-status"),
]
