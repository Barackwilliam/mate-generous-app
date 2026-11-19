from django.db import migrations

CATEGORIES = [
    ("Kesha la Usiku", "kesha-la-usiku", "nights_stay", True,
     "Ibada ya kila usiku: andiko kuu, tafakari, matumizi ya vitendo na sala."),
    ("Asubuhi ya Tumaini", "asubuhi-ya-tumaini", "wb_sunny", False,
     "Ibada fupi za asubuhi kuanza siku kwa imani, mwelekeo na kusudi."),
    ("Weary Souls", "weary-souls", "favorite", False,
     "Kwa waliochoka na waliovunjika moyo: kusubiri, kukataliwa, kuanza upya, msamaha na tumaini."),
    ("Marriage & Family", "marriage-family", "family_restroom", False,
     "Maandalizi ya ndoa, kuimarisha ndoa, mawasiliano, malezi na ibada ya familia."),
    ("Bible Study", "bible-study", "menu_book", False, ""),
    ("Unabii", "unabii", "visibility", False,
     "Danieli, Ufunuo, Jumbe za Malaika Watatu, Kuja kwa Yesu mara ya Pili na ratiba za unabii."),
    ("Sermons", "sermons", "record_voice_over", False,
     "Maktaba ya mahubiri kwa wachungaji, wazee, wainjilisti na wahubiri walei."),
    ("Leadership", "leadership", "groups", False,
     "Rasilimali za kichungaji: uongozi, mafunzo ya wazee, ibada, uinjilisti na uwakili."),
    ("Prayer", "prayer", "volunteer_activism", False, ""),
    ("Books", "books", "auto_stories", False, ""),
    ("Courses", "courses", "school", False, ""),
]

SECTIONS = [
    ("Endelea kusoma", "continue_reading", None),
    ("Jumbe za karibuni", "latest", None),
    ("Tunakupendekezea", "featured", None),
    ("Asubuhi ya Tumaini", "category", "asubuhi-ya-tumaini"),
    ("Series maarufu", "series_list", None),
    ("Sikiliza", "audio", None),
]


def seed(apps, schema_editor):
    Category = apps.get_model("catalog", "Category")
    HomeSection = apps.get_model("catalog", "HomeSection")
    for order, (name, slug, icon, flagship, description) in enumerate(CATEGORIES):
        Category.objects.get_or_create(
            slug=slug,
            defaults={"name": name, "icon": icon, "is_flagship": flagship,
                      "description": description, "order": order * 10, "status": "published"},
        )
    if not HomeSection.objects.exists():
        for order, (title, kind, cat_slug) in enumerate(SECTIONS):
            HomeSection.objects.create(
                title=title, kind=kind, order=order * 10,
                category=Category.objects.filter(slug=cat_slug).first() if cat_slug else None,
            )


class Migration(migrations.Migration):
    dependencies = [("catalog", "0001_initial")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
