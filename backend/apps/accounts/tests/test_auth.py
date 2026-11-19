from rest_framework.test import APITestCase


class AuthTests(APITestCase):
    def register(self, **kw):
        data = {"email": "Neema@Example.com", "phone": "0712 345 678", "full_name": "Neema",
                "password": "Imani-Thabiti-2026", **kw}
        return self.client.post("/api/auth/register/", data, format="json")

    def test_register_then_login_with_email_or_phone(self):
        r = self.register()
        self.assertEqual(r.status_code, 201, r.content)
        self.assertEqual(r.json()["user"]["phone"], "255712345678")
        for identifier in ("neema@example.com", "+255712345678", "0712345678"):
            r = self.client.post("/api/auth/login/", {"identifier": identifier, "password": "Imani-Thabiti-2026"})
            self.assertEqual(r.status_code, 200, identifier)
            self.assertIn("access", r.json()["tokens"])

    def test_wrong_password_and_duplicates_are_refused(self):
        self.register()
        r = self.client.post("/api/auth/login/", {"identifier": "neema@example.com", "password": "wrong"})
        self.assertEqual(r.status_code, 400)
        self.assertEqual(self.register(phone="0799999999").status_code, 400)  # same email
        self.assertEqual(self.register(email="other@example.com").status_code, 400)  # same phone

    def test_weak_password_is_refused(self):
        self.assertEqual(self.register(password="12345678").status_code, 400)

    def test_profile_update(self):
        token = self.register().json()["tokens"]["access"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        r = self.client.patch("/api/auth/me/", {"full_name": "Neema J."}, format="json")
        self.assertEqual(r.json()["full_name"], "Neema J.")
