from datetime import timedelta

from django.utils import timezone
from rest_framework.test import APITestCase

from apps.subscriptions.models import Purchase, Subscription, create_subscription

from . import factories as f


class ReaderAccessTests(APITestCase):
    def setUp(self):
        self.reader = f.user()
        self.free = f.content("Bure", access_level="free")
        self.locked = f.content("Kwa Wanachama", access_level="subscriber", share_excerpt="Kipande tu.")
        self.premium = f.content("Hubiri", access_level="premium", category=f.category("sermons"))

    def get(self, item):
        return self.client.get(f"/api/contents/{item.slug}/").json()

    def test_free_content_opens_for_anyone(self):
        data = self.get(self.free)
        self.assertFalse(data["is_locked"])
        self.assertIn("Kilio", data["body"])

    def test_locked_content_returns_preview_not_text(self):
        data = self.get(self.locked)
        self.assertTrue(data["is_locked"])
        self.assertIsNone(data["body"])
        self.assertIsNone(data["prayer"])
        self.assertEqual(data["preview"], "Kipande tu.")
        self.assertEqual(data["share"]["excerpt"], "Kipande tu.")
        self.assertTrue(data["unlock"]["subscribe"])

    def test_standard_subscription_opens_subscriber_but_not_premium(self):
        create_subscription(self.reader, f.plan(), source="manual")
        self.client.force_authenticate(self.reader)
        self.assertFalse(self.get(self.locked)["is_locked"])
        self.assertTrue(self.get(self.premium)["is_locked"])

    def test_premium_subscription_opens_everything(self):
        create_subscription(self.reader, f.plan("p", tier="premium"), source="manual")
        self.client.force_authenticate(self.reader)
        self.assertFalse(self.get(self.locked)["is_locked"])
        self.assertFalse(self.get(self.premium)["is_locked"])

    def test_expired_subscription_falls_back_to_free_but_keeps_purchases(self):
        sub = create_subscription(self.reader, f.plan(), source="manual")
        Purchase.objects.create(user=self.reader, content=self.premium, amount=3000)
        Subscription.objects.filter(pk=sub.pk).update(expires_at=timezone.now() - timedelta(minutes=1))
        self.client.force_authenticate(self.reader)
        self.assertTrue(self.get(self.locked)["is_locked"])
        self.assertFalse(self.get(self.premium)["is_locked"])
        self.assertIsNone(self.client.get("/api/subscriptions/me/").json()["tier"])

    def test_buying_a_series_opens_every_item_in_it(self):
        book = f.series("Kitabu", access_level="subscriber", price=10000)
        chapter = f.content("Sura 1", series=book, category=book.category)
        Purchase.objects.create(user=self.reader, series=book, amount=10000)
        self.client.force_authenticate(self.reader)
        self.assertFalse(self.get(chapter)["is_locked"])

    def test_series_level_applies_to_free_items_inside_it(self):
        book = f.series("Kitabu", access_level="subscriber")
        chapter = f.content("Sura 1", series=book, category=book.category, access_level="free")
        self.assertTrue(self.get(chapter)["is_locked"])

    def test_audio_is_refused_when_locked(self):
        self.locked.audio_url = "https://cdn.example.com/a.mp3"
        self.locked.save()
        self.assertEqual(self.client.get(f"/api/contents/{self.locked.slug}/audio/").status_code, 403)
        self.client.force_authenticate(self.reader)
        self.assertEqual(self.client.get(f"/api/contents/{self.locked.slug}/audio/").status_code, 403)
        create_subscription(self.reader, f.plan(), source="manual")
        r = self.client.get(f"/api/contents/{self.locked.slug}/audio/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["url"], "https://cdn.example.com/a.mp3")

    def test_list_never_includes_body(self):
        rows = self.client.get("/api/contents/").json()["results"]
        self.assertTrue(rows)
        self.assertTrue(all("body" not in row for row in rows))


class VisibilityTests(APITestCase):
    def test_drafts_scheduled_and_archived_are_hidden(self):
        f.content("Rasimu", status="draft")
        f.content("Kesho", publish_at=timezone.now() + timedelta(days=1))
        archived = f.category("zamani", status="archived")
        f.content("Ya Zamani", category=archived)
        visible = f.content("Inaonekana")
        titles = [c["title"] for c in self.client.get("/api/contents/").json()["results"]]
        self.assertEqual(titles, [visible.title])
        self.assertEqual(self.client.get("/api/contents/kesho/").status_code, 404)

    def test_archived_category_leaves_the_category_list(self):
        f.category("hai")
        f.category("zamani", status="archived")
        slugs = [c["slug"] for c in self.client.get("/api/categories/").json()]
        self.assertIn("hai", slugs)
        self.assertNotIn("zamani", slugs)


class NavigationAndSearchTests(APITestCase):
    def test_next_previous_follow_series_order(self):
        s = f.series("Ufunuo")
        c1 = f.content("Sura ya Kwanza", series=s, category=s.category, order_in_series=1)
        c3 = f.content("Sura ya Tatu", series=s, category=s.category, order_in_series=3)
        c2 = f.content("Sura ya Pili", series=s, category=s.category, order_in_series=2)
        nav = self.client.get(f"/api/contents/{c2.slug}/").json()["navigation"]
        self.assertEqual(nav["previous"]["slug"], c1.slug)
        self.assertEqual(nav["next"]["slug"], c3.slug)
        self.assertIsNone(self.client.get(f"/api/contents/{c3.slug}/").json()["navigation"]["next"])

    def test_next_previous_by_date_outside_a_series(self):
        now = timezone.now()
        old = f.content("Jana", publish_at=now - timedelta(days=2))
        new = f.content("Leo", publish_at=now - timedelta(hours=1))
        self.assertEqual(self.client.get(f"/api/contents/{old.slug}/").json()["navigation"]["next"]["slug"], new.slug)

    def test_search_by_scripture_series_and_author(self):
        from apps.catalog.models import Author

        author = Author.objects.create(name="Mch. Yohana")
        s = f.series("Jumbe za Malaika Watatu")
        f.content("A", scripture_reference="Zaburi 30:5")
        f.content("B", series=s, category=s.category)
        f.content("C", author=author)
        f.content("D")
        for q, expected in (("zaburi 30", "A"), ("malaika", "B"), ("yohana", "C")):
            titles = [c["title"] for c in self.client.get("/api/contents/", {"q": q}).json()["results"]]
            self.assertEqual(titles, [expected], q)


class HomeTests(APITestCase):
    def test_tonight_is_latest_flagship_message(self):
        flagship = f.category("kesha-la-usiku", is_flagship=True)
        f.content("Jana Usiku", category=flagship, publish_at=timezone.now() - timedelta(days=1))
        f.content("Leo Usiku", category=flagship, publish_at=timezone.now() - timedelta(minutes=5))
        f.content("Kesho Usiku", category=flagship, publish_at=timezone.now() + timedelta(hours=3))
        data = self.client.get("/api/home/").json()
        self.assertEqual(data["tonight"]["title"], "Leo Usiku")
        kinds = [s["kind"] for s in data["sections"]]
        self.assertIn("latest", kinds)
        self.assertNotIn("continue_reading", kinds)  # anonymous visitor

    def test_continue_reading_for_signed_in_user(self):
        reader = f.user()
        item = f.content("Nusu")
        self.client.force_authenticate(reader)
        self.client.put(f"/api/library/{item.slug}/progress/", {"percent": 40}, format="json")
        sections = {s["kind"]: s for s in self.client.get("/api/home/").json()["sections"]}
        self.assertEqual(sections["continue_reading"]["items"][0]["slug"], item.slug)
