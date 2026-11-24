import json
from io import StringIO

from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.utils import timezone
from rest_framework.test import APITestCase

from apps.accounts.models import User
from apps.catalog import importer
from apps.catalog.models import Author, Content, Series

GOOD = {
    "authors": [{"key": "mch-yohana", "name": "Mch. Yohana Mrema", "title": "Mchungaji"}],
    "series": [{"slug": "ahadi-gizani", "title": "Ahadi Gizani", "category": "kesha-la-usiku", "author": "mch-yohana", "access_level": "free"}],
    "contents": [
        {
            "slug": "nuru-ya-asubuhi", "title": "Nuru ya Asubuhi", "category": "kesha-la-usiku", "series": "ahadi-gizani",
            "order_in_series": 1, "author": "mch-yohana", "kind": "devotional",
            "scripture_reference": "Zaburi 46:5", "scripture_text": "Mungu yu katikati yake.",
            "summary": "Mungu yupo hata usiku.", "body_html": "<p>Aya ya kwanza.</p><h2>Kichwa</h2><p onclick='x()'>Pili<script>alert(1)</script></p>",
            "application": "Omba leo.", "prayer": "Bwana, asante.", "access_level": "subscriber",
            "topics": ["Tumaini", "Imani"], "publish_date": "2026-12-01", "featured": True,
        },
        {"title": "Ujumbe wa Pili", "category": "asubuhi-ya-tumaini", "body_html": "Aya moja.\n\nAya mbili."},
    ],
}


class ImporterTests(APITestCase):
    def setUp(self):
        call_command("seed_sample_content", stdout=StringIO())

    def test_import_creates_everything_and_cleans_html(self):
        r = importer.load(GOOD)
        self.assertEqual(r.errors, [])
        self.assertEqual((r.created, r.series), (2, 1))
        item = Content.objects.get(slug="nuru-ya-asubuhi")
        self.assertEqual(item.series.slug, "ahadi-gizani")
        self.assertEqual(item.author.name, "Mch. Yohana Mrema")
        self.assertEqual(item.access_level, "subscriber")
        self.assertNotIn("script", item.body)
        self.assertNotIn("onclick", item.body)
        self.assertIn("<h2>Kichwa</h2>", item.body)
        self.assertEqual(timezone.localtime(item.publish_at).hour, 18)
        self.assertEqual(sorted(item.topics.values_list("name", flat=True)), ["Imani", "Tumaini"])
        self.assertEqual(Content.objects.get(slug="ujumbe-wa-pili").body, "<p>Aya moja.</p><p>Aya mbili.</p>")

    def test_reimport_updates_instead_of_duplicating(self):
        importer.load(GOOD)
        changed = json.loads(json.dumps(GOOD))
        changed["contents"][0]["title"] = "Nuru ya Asubuhi (imesahihishwa)"
        r = importer.load(changed)
        self.assertEqual((r.created, r.updated), (0, 2))
        self.assertEqual(Content.objects.filter(slug="nuru-ya-asubuhi").count(), 1)

    def test_one_bad_item_saves_nothing_and_says_which(self):
        bad = json.loads(json.dumps(GOOD))
        bad["contents"][1]["category"] = "haipo"
        before = Content.objects.count()
        r = importer.load(bad)
        self.assertEqual(Content.objects.count(), before)
        self.assertTrue(any("Ujumbe wa Pili" in e and "haipo" in e for e in r.errors))

    def test_replace_samples_removes_only_the_samples(self):
        own = Content.objects.create(title="Wangu", slug="wangu", category_id=Content.objects.first().category_id,
                                     status="published", body="x")
        r = importer.load(GOOD, replace_samples=True)
        self.assertEqual(r.removed_samples, 16)
        self.assertFalse(Content.objects.filter(slug="kilio-hudumu-usiku-mmoja").exists())
        self.assertFalse(Author.objects.filter(slug="mate-sample").exists())
        self.assertFalse(Series.objects.filter(slug="danieli").exists())
        self.assertTrue(Content.objects.filter(pk=own.pk).exists())

    def test_dry_run_and_broken_json(self):
        r = importer.load(GOOD, dry_run=True)
        self.assertEqual((r.created, r.errors), (2, []))
        self.assertFalse(Content.objects.filter(slug="nuru-ya-asubuhi").exists())
        self.assertIn("JSON si sahihi", importer.load_text("{\"contents\": [").errors[0])

    def test_command(self):
        import tempfile

        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
            json.dump(GOOD, f)
        out = StringIO()
        call_command("import_content", f.name, "--replace-samples", stdout=out)
        self.assertIn("Jumbe mpya: 2", out.getvalue())

    def test_admin_upload_page(self):
        admin = User.objects.create_superuser("admin@example.com", "x", full_name="A")
        self.client.force_login(admin)
        url = "/admin/catalog/content/import-json/"
        self.assertEqual(self.client.get(url).status_code, 200)
        upload = SimpleUploadedFile("jumbe.json", json.dumps(GOOD).encode(), content_type="application/json")
        r = self.client.post(url, {"files": [upload], "replace_samples": "on"})
        self.assertEqual(r.status_code, 200)
        self.assertContains(r, "Jumbe mpya: 2")
        self.assertTrue(Content.objects.filter(slug="nuru-ya-asubuhi").exists())
        self.assertFalse(Content.objects.filter(slug="nuru-gizani").exists())
