from io import StringIO

from django.core.management import call_command
from rest_framework.test import APITestCase

from apps.catalog.models import Category, Content


class SeedTests(APITestCase):
    def test_seed_fills_the_app_and_is_safe_to_rerun(self):
        call_command("seed_sample_content", stdout=StringIO())
        count = Content.objects.count()
        self.assertGreaterEqual(count, 15)
        call_command("seed_sample_content", stdout=StringIO())
        self.assertEqual(Content.objects.count(), count)

        kesha = Category.objects.get(slug="kesha-la-usiku")
        self.assertEqual((kesha.icon, kesha.accent_color), ("cross", "#F5B544"))
        self.assertEqual(Category.objects.get(slug="unabii").name_en, "Prophecy")

        home = self.client.get("/api/home/").json()
        self.assertEqual(home["tonight"]["title"], "Kilio Hudumu Usiku Mmoja")
        self.assertTrue(any(s["items"] for s in home["sections"] if "items" in s))

    def test_once_adds_samples_beside_existing_content_but_never_restores_deleted_ones(self):
        from . import factories as f

        f.content("Ujumbe wa admin")
        call_command("seed_sample_content", "--once", stdout=StringIO())
        self.assertTrue(Content.objects.filter(slug="nuru-gizani").exists())
        Content.objects.filter(slug="nuru-gizani").delete()
        call_command("seed_sample_content", "--once", stdout=StringIO())
        self.assertFalse(Content.objects.filter(slug="nuru-gizani").exists())
