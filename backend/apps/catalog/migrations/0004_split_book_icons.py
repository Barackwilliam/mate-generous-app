from django.db import migrations

# Bible Study and Books shared the "book" icon; the app now has a picture for each.
NEW = {"bible-study": "bible", "books": "books"}


def forwards(apps, schema_editor):
    Category = apps.get_model("catalog", "Category")
    for slug, icon in NEW.items():
        Category.objects.filter(slug=slug, icon__in=["book", "menu_book", "auto_stories", ""]).update(icon=icon)


class Migration(migrations.Migration):
    dependencies = [("catalog", "0003_category_description_en_category_name_en_and_more")]
    operations = [migrations.RunPython(forwards, migrations.RunPython.noop)]
