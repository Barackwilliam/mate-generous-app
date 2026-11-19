from rest_framework import permissions, serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from . import entitlements
from .models import Plan, Subscription


class PlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = Plan
        fields = ("id", "code", "name", "description", "tier", "duration_days", "price")


class SubscriptionSerializer(serializers.ModelSerializer):
    plan = PlanSerializer()
    is_current = serializers.BooleanField()

    class Meta:
        model = Subscription
        fields = ("id", "plan", "starts_at", "expires_at", "status", "is_current")


class PlanListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return Response(PlanSerializer(Plan.objects.filter(is_active=True), many=True).data)


class MySubscriptionView(APIView):
    """Current access, plus history. Expired users simply show tier=None (free)."""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        ent = entitlements.for_user(request.user)
        history = Subscription.objects.filter(user=request.user).select_related("plan")[:20]
        return Response({
            "tier": ent.tier,
            "expires_at": ent.expires_at,
            "renewal_status": ent.renewal_status,
            "history": SubscriptionSerializer(history, many=True).data,
        })
