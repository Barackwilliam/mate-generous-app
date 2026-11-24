"""python manage.py import_content file1.json [file2.json ...] [--replace-samples] [--dry-run]

Same importer as the admin's "Pakia maudhui (JSON)" page. See docs/CONTENT_IMPORT.md.
"""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from apps.catalog.importer import load_text


class Command(BaseCommand):
    help = "Import devotionals, series and authors from JSON files."

    def add_arguments(self, parser):
        parser.add_argument("files", nargs="+")
        parser.add_argument("--replace-samples", action="store_true", help="Delete the built-in sample content first.")
        parser.add_argument("--dry-run", action="store_true", help="Check the files without saving anything.")

    def handle(self, *args, **opts):
        failed = False
        for i, name in enumerate(opts["files"]):
            path = Path(name)
            if not path.exists():
                raise CommandError(f"{name}: file not found")
            report = load_text(path.read_text(encoding="utf-8"),
                               replace_samples=opts["replace_samples"] and i == 0, dry_run=opts["dry_run"])
            self.stdout.write(f"{name}: {report.summary()}")
            for w in report.warnings:
                self.stdout.write(self.style.WARNING(f"  ! {w}"))
            for e in report.errors:
                self.stdout.write(self.style.ERROR(f"  x {e}"))
            failed |= bool(report.errors)
        if failed:
            raise CommandError("Some files had errors; those files were not saved.")
