from rest_framework.test import APITestCase

from apps.catalog.tests import factories as f


class LibraryTests(APITestCase):
    def setUp(self):
        self.reader = f.user()
        self.item = f.content()
        self.client.force_authenticate(self.reader)

    def test_bookmark_favourite_and_history(self):
        base = f"/api/library/{self.item.slug}"
        self.assertEqual(self.client.put(f"{base}/bookmark/").status_code, 204)
        self.assertEqual(self.client.put(f"{base}/bookmark/").status_code, 204)  # idempotent
        self.client.put(f"{base}/favourite/")
        self.client.put(f"{base}/progress/", {"percent": 100}, format="json")

        lib = self.client.get("/api/library/").json()
        self.assertEqual(len(lib["bookmarks"]), 1)
        self.assertEqual(len(lib["favourites"]), 1)
        self.assertTrue(lib["history"][0]["completed"])

        state = self.client.get(f"/api/contents/{self.item.slug}/").json()["user_state"]
        self.assertTrue(state["is_bookmarked"])

        self.client.delete(f"{base}/bookmark/")
        self.assertEqual(self.client.get("/api/library/").json()["bookmarks"], [])

    def test_unknown_kind_is_404(self):
        self.assertEqual(self.client.put(f"/api/library/{self.item.slug}/like/").status_code, 404)

    def test_library_requires_login(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get("/api/library/").status_code, 401)


class StatsTests(APITestCase):
    def test_streak_and_counts(self):
        from datetime import timedelta

        from django.utils import timezone

        from apps.library.models import ReadingDay

        reader = f.user()
        today = timezone.localdate()
        for d in (1, 2, 4):
            ReadingDay.objects.create(user=reader, date=today - timedelta(days=d))
        self.client.force_authenticate(reader)
        item = f.content()
        self.client.put(f"/api/library/{item.slug}/progress/", {"percent": 100}, format="json")
        self.client.put(f"/api/library/{item.slug}/favourite/")
        stats = self.client.get("/api/library/").json()["stats"]
        self.assertEqual(stats, {"streak_days": 3, "completed": 1, "saved": 1})
