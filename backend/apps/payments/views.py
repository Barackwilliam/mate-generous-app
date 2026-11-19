import logging

from django.shortcuts import get_object_or_404
from rest_framework import permissions, serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import normalize_phone
from apps.catalog.models import Content, PublishStatus, Series
from apps.subscriptions.models import Plan

from . import services
from .gateways import CallbackRejected, get_gateway
from .models import Transaction

log = logging.getLogger(__name__)


class StartPaymentSerializer(serializers.Serializer):
    plan_id = serializers.IntegerField(required=False, allow_null=True)
    content_id = serializers.IntegerField(required=False, allow_null=True)
    series_id = serializers.IntegerField(required=False, allow_null=True)
    phone = serializers.CharField()
    network = serializers.ChoiceField(choices=Transaction.Network.choices)

    def validate_phone(self, value):
        phone = normalize_phone(value)
        if not phone or not phone.startswith("255") or len(phone) != 12:
            raise serializers.ValidationError("Weka namba sahihi ya simu, mfano 0712345678.")
        return phone

    def validate(self, attrs):
        chosen = [k for k in ("plan_id", "content_id", "series_id") if attrs.get(k)]
        if len(chosen) != 1:
            raise serializers.ValidationError("Chagua kitu kimoja cha kulipia.")
        return attrs


class TransactionSerializer(serializers.ModelSerializer):
    item = serializers.CharField(source="item_name")

    class Meta:
        model = Transaction
        fields = ("reference", "kind", "item", "amount", "currency", "phone", "network",
                  "status", "failure_reason", "created_at", "completed_at")


class StartPaymentView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_scope = "payments"

    def post(self, request):
        s = StartPaymentSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        target = {}
        if d.get("plan_id"):
            target["plan"] = get_object_or_404(Plan, pk=d["plan_id"])
        elif d.get("content_id"):
            target["content"] = get_object_or_404(Content.objects.published(), pk=d["content_id"])
        else:
            target["series"] = get_object_or_404(Series, pk=d["series_id"], status=PublishStatus.PUBLISHED)
        try:
            txn = services.start_payment(request.user, phone=d["phone"], network=d["network"], **target)
        except services.PaymentError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(TransactionSerializer(txn).data, status=status.HTTP_201_CREATED)


class TransactionStatusView(APIView):
    """The app polls this after the USSD prompt; it asks the gateway, not the phone."""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, reference):
        txn = get_object_or_404(Transaction, reference=reference, user=request.user)
        txn = services.refresh_status(txn)
        return Response(TransactionSerializer(txn).data)


class MyTransactionsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        txns = Transaction.objects.filter(user=request.user).select_related("plan", "content", "series")[:50]
        return Response(TransactionSerializer(txns, many=True).data)


class GatewayCallbackView(APIView):
    """Server-to-server notification from the payment gateway."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request, gateway):
        try:
            reference, result = get_gateway(gateway).parse_callback(request)
        except RuntimeError:
            return Response(status=status.HTTP_404_NOT_FOUND)
        except (CallbackRejected, ValueError, KeyError):
            log.warning("Rejected %s payment callback", gateway)
            return Response(status=status.HTTP_400_BAD_REQUEST)
        txn = Transaction.objects.filter(reference=reference, gateway=gateway).first()
        if txn is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        services.apply_result(txn.pk, result, source="callback")
        return Response({"ok": True})
