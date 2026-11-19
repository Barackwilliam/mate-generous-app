from django.db import migrations

# Prices are placeholders and the plans start switched off: the client sets
# real prices in the admin and then activates each plan.
PLANS = [
    ("monthly", "Mwezi 1", "standard", 30),
    ("quarterly", "Miezi 3", "standard", 90),
    ("six-months", "Miezi 6", "standard", 180),
    ("annual", "Mwaka 1", "standard", 365),
    ("premium-annual", "Premium (Mwaka 1)", "premium", 365),
]


def seed(apps, schema_editor):
    Plan = apps.get_model("subscriptions", "Plan")
    for order, (code, name, tier, days) in enumerate(PLANS):
        Plan.objects.get_or_create(
            code=code,
            defaults={"name": name, "tier": tier, "duration_days": days, "price": 0,
                      "is_active": False, "order": order * 10},
        )


class Migration(migrations.Migration):
    dependencies = [("subscriptions", "0001_initial")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
