import hashlib
import hmac
import json
from datetime import timedelta

from django.contrib.admin.sites import site
from django.core.cache import cache
from django.test import RequestFactory, override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from apps.audit.models import AuditLog
from apps.catalog.tests import factories as f
from apps.payments.gateways import GatewayResult
from apps.payments.models import Transaction
from apps.payments.services import apply_result
from apps.subscriptions.models import Purchase, Subscription

SECRET = "test-callback-secret"


@override_settings(PAYMENT_GATEWAY="sandbox", PAYMENT_CALLBACK_SECRET=SECRET)
class PaymentFlowTests(APITestCase):
    def setUp(self):
        cache.clear()  # throttle counters
        self.reader = f.user()
        self.plan = f.plan(days=30, price=5000)
        self.client.force_authenticate(self.reader)

    def start(self, **kw):
        data = {"plan_id": self.plan.pk, "phone": "0712345678", "network": "mpesa", **kw}
        return self.client.post("/api/payments/start/", data, format="json")

    def test_successful_payment_activates_subscription_once(self):
        r = self.start()
        self.assertEqual(r.status_code, 201, r.content)
        ref = r.json()["reference"]
        self.assertEqual(r.json()["status"], "pending")
        self.assertFalse(Subscription.objects.exists())

        for _ in range(3):  # the app polls repeatedly
            self.assertEqual(self.client.get(f"/api/payments/{ref}/").json()["status"], "success")
        self.assertEqual(Subscription.objects.count(), 1)
        sub = Subscription.objects.get()
        self.assertAlmostEqual(sub.expires_at - sub.starts_at, timedelta(days=30))
        self.assertEqual(self.client.get("/api/subscriptions/me/").json()["tier"], "standard")

    def test_declined_payment_gives_nothing(self):
        ref = self.start(phone="0712340000").json()["reference"]
        self.assertEqual(self.client.get(f"/api/payments/{ref}/").json()["status"], "failed")
        self.assertFalse(Subscription.objects.exists())

    def test_renewing_while_active_extends_instead_of_overlapping(self):
        for _ in range(2):
            ref = self.start().json()["reference"]
            self.client.get(f"/api/payments/{ref}/")
        first, second = Subscription.objects.order_by("starts_at")
        self.assertEqual(second.starts_at, first.expires_at)
        self.assertAlmostEqual(self.client.get("/api/subscriptions/me/").json()["expires_at"] and
                               (second.expires_at - timezone.now()).days, 59, delta=1)

    def test_inactive_or_unpriced_plan_cannot_be_bought(self):
        self.plan.is_active = False
        self.plan.save()
        self.assertEqual(self.start().status_code, 400)

    def test_standalone_purchase(self):
        item = f.content("Kitabu Kidogo", access_level="premium", price=3000)
        ref = self.start(plan_id=None, content_id=item.pk).json()["reference"]
        self.client.get(f"/api/payments/{ref}/")
        self.assertTrue(Purchase.objects.filter(user=self.reader, content=item).exists())
        self.assertFalse(self.client.get(f"/api/contents/{item.slug}/").json()["is_locked"])
        self.assertEqual(self.start(plan_id=None, content_id=item.pk).status_code, 400)  # already owned

    def test_item_without_price_is_not_for_sale(self):
        item = f.content("Si ya Kuuzwa")
        self.assertEqual(self.start(plan_id=None, content_id=item.pk).status_code, 400)

    def test_bad_phone_is_refused(self):
        self.assertEqual(self.start(phone="12").status_code, 400)

    def callback(self, body, secret=SECRET):
        raw = json.dumps(body).encode()
        sig = hmac.new(secret.encode(), raw, hashlib.sha256).hexdigest()
        return self.client.post("/api/payments/callback/sandbox/", raw, content_type="application/json",
                                HTTP_X_SIGNATURE=sig)

    def test_signed_callback_activates_and_repeats_are_harmless(self):
        ref = self.start().json()["reference"]
        body = {"reference": ref, "status": "success", "amount": 5000}
        self.assertEqual(self.callback(body).status_code, 200)
        self.assertEqual(self.callback(body).status_code, 200)
        self.assertEqual(Subscription.objects.count(), 1)

    def test_forged_callback_is_rejected(self):
        ref = self.start().json()["reference"]
        r = self.callback({"reference": ref, "status": "success", "amount": 5000}, secret="guess")
        self.assertEqual(r.status_code, 400)
        self.assertEqual(Transaction.objects.get(reference=ref).status, "pending")

    def test_underpayment_fails_the_transaction(self):
        ref = self.start().json()["reference"]
        self.callback({"reference": ref, "status": "success", "amount": 100})
        txn = Transaction.objects.get(reference=ref)
        self.assertEqual(txn.status, "failed")
        self.assertIn("mismatch", txn.failure_reason)
        self.assertFalse(Subscription.objects.exists())

    def test_users_cannot_see_each_others_transactions(self):
        ref = self.start().json()["reference"]
        self.client.force_authenticate(f.user("mwingine@example.com"))
        self.assertEqual(self.client.get(f"/api/payments/{ref}/").status_code, 404)


@override_settings(PAYMENT_GATEWAY="sandbox")
class ManualActionAuditTests(APITestCase):
    def setUp(self):
        self.staff = f.user("admin@example.com", is_staff=True, is_superuser=True)
        self.reader = f.user()
        self.plan = f.plan()

    def test_manual_confirmation_activates_and_is_audited(self):
        txn = Transaction.objects.create(user=self.reader, kind="subscription", plan=self.plan,
                                         amount=5000, phone="255712345678", network="airtel", gateway="sandbox")
        apply_result(txn.pk, GatewayResult(status="success"), source="manual", actor=self.staff,
                     reason="Customer showed SMS receipt")
        sub = Subscription.objects.get(user=self.reader)
        self.assertEqual(sub.source, "manual")
        log = AuditLog.objects.get(action=AuditLog.Action.TRANSACTION_MANUAL_CONFIRM)
        self.assertEqual(log.actor, self.staff)
        self.assertEqual(log.target_user, self.reader)
        self.assertIsNotNone(log.created_at)

    def test_admin_grant_requires_reason_and_is_audited(self):
        self.client.force_login(self.staff)
        url = "/admin/subscriptions/subscription/add/"
        data = {"user": self.reader.pk, "plan": self.plan.pk,
                "starts_at_0": timezone.localtime().strftime("%Y-%m-%d"),
                "starts_at_1": timezone.localtime().strftime("%H:%M:%S"), "note": ""}
        self.client.post(url, data)
        self.assertFalse(Subscription.objects.exists())
        data["note"] = "Zawadi kwa mchungaji wa wilaya"
        r = self.client.post(url, data)
        self.assertEqual(r.status_code, 302, r.content[:2000])
        sub = Subscription.objects.get()
        self.assertEqual(sub.source, "manual")
        log = AuditLog.objects.get(action=AuditLog.Action.SUBSCRIPTION_MANUAL_GRANT)
        self.assertEqual((log.actor, log.reason), (self.staff, "Zawadi kwa mchungaji wa wilaya"))

    def test_audit_log_cannot_be_edited_or_deleted_in_admin(self):
        admin = site._registry[AuditLog]
        request = RequestFactory().get("/")
        request.user = self.staff
        self.assertFalse(admin.has_change_permission(request))
        self.assertFalse(admin.has_delete_permission(request))
