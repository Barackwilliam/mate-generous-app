import re

from django.core import mail
from django.core.cache import cache
from rest_framework.test import APITestCase

from apps.accounts.models import PasswordResetCode, User


class PasswordResetTests(APITestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user("neema@example.com", "Imani-Thabiti-2026", full_name="Neema", phone="0712345678")

    def forgot(self, identifier):
        return self.client.post("/api/auth/password/forgot/", {"identifier": identifier}, format="json")

    def code_from_email(self):
        return re.search(r"\b(\d{6})\b", mail.outbox[-1].body).group(1)

    def reset(self, code, password="Mpya-Kabisa-2027", identifier="0712345678"):
        return self.client.post("/api/auth/password/reset/",
                                {"identifier": identifier, "code": code, "new_password": password}, format="json")

    def test_code_by_phone_resets_and_signs_in(self):
        self.assertEqual(self.forgot("0712 345 678").status_code, 200)
        self.assertEqual(mail.outbox[-1].to, ["neema@example.com"])
        r = self.reset(self.code_from_email())
        self.assertEqual(r.status_code, 200, r.content)
        self.assertIn("access", r.json()["tokens"])
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("Mpya-Kabisa-2027"))
        self.assertEqual(self.reset(self.code_from_email(), password="Nyingine-2028").status_code, 400)  # single use

    def test_unknown_account_gets_same_answer_and_no_email(self):
        r = self.forgot("hayupo@example.com")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(mail.outbox), 0)

    def test_wrong_codes_are_limited(self):
        self.forgot("neema@example.com")
        good = self.code_from_email()
        bad = "000000" if good != "000000" else "111111"
        for _ in range(PasswordResetCode.MAX_ATTEMPTS):
            self.assertEqual(self.reset(bad).status_code, 400)
        self.assertEqual(self.reset(good).status_code, 400)  # locked after too many tries

    def test_new_request_cancels_the_old_code_and_weak_password_is_refused(self):
        self.forgot("neema@example.com")
        old = self.code_from_email()
        self.forgot("neema@example.com")
        new = self.code_from_email()
        if old != new:
            self.assertEqual(self.reset(old).status_code, 400)
        self.assertEqual(self.reset(new, password="12345678").status_code, 400)
        self.assertEqual(self.reset(new).status_code, 200)

    def test_stored_code_is_not_the_plain_code(self):
        self.forgot("neema@example.com")
        self.assertNotEqual(PasswordResetCode.objects.get().code_hash, self.code_from_email())
