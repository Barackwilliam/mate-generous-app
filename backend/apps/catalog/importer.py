"""Bulk import of content from JSON (e.g. written with ChatGPT).

The file format is documented in docs/CONTENT_IMPORT.md. Items are matched by
slug, so importing the same file twice updates instead of duplicating. Body
HTML is reduced to a safe set of tags.
"""

import json
from dataclasses import dataclass, field
from datetime import datetime, time, timedelta
from html.parser import HTMLParser

from django.db import transaction
from django.utils import timezone
from django.utils.text import slugify

from .management.commands.seed_sample_content import CONTENT as SAMPLE_CONTENT
from .management.commands.seed_sample_content import SERIES as SAMPLE_SERIES
from .models import AccessLevel, Author, Category, Content, PublishStatus, Series, Topic

KINDS = {k for k, _ in Content.Kind.choices}
LEVELS = {k for k, _ in AccessLevel.choices}
ALLOWED_TAGS = {"p", "h2", "h3", "blockquote", "strong", "em", "b", "i", "ul", "ol", "li", "br", "hr"}
SAMPLE_AUTHORS = ("mate-sample", "rehema-sample")


class _Cleaner(HTMLParser):
    """Keeps only simple formatting tags; drops attributes, scripts and styles."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []
        self.skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style"):
            self.skip += 1
        elif tag in ALLOWED_TAGS and not self.skip:
            self.out.append(f"<{tag}>")

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.skip = max(0, self.skip - 1)
        elif tag in ALLOWED_TAGS and tag not in ("br", "hr") and not self.skip:
            self.out.append(f"</{tag}>")

    def handle_data(self, data):
        if not self.skip:
            self.out.append(data.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def clean_html(text):
    text = (text or "").strip()
    if not text:
        return ""
    if "<" not in text:  # plain paragraphs separated by blank lines
        return "".join(f"<p>{p.strip()}</p>" for p in text.split("\n\n") if p.strip())
    c = _Cleaner()
    c.feed(text)
    return "".join(c.out)


@dataclass
class Report:
    created: int = 0
    updated: int = 0
    series: int = 0
    authors: int = 0
    removed_samples: int = 0
    errors: list = field(default_factory=list)
    warnings: list = field(default_factory=list)

    def summary(self):
        return (f"Jumbe mpya: {self.created}, zilizosasishwa: {self.updated}, series: {self.series}, "
                f"waandishi: {self.authors}, sampuli zilizofutwa: {self.removed_samples}, makosa: {len(self.errors)}")


def remove_samples():
    """Delete the built-in sample content, series and authors (not the admin's own)."""
    samples = Content.objects.filter(slug__in=[c[0] for c in SAMPLE_CONTENT], author__slug__in=SAMPLE_AUTHORS)
    count = samples.count()
    samples.delete()
    Series.objects.filter(slug__in=[s[0] for s in SAMPLE_SERIES], contents__isnull=True).delete()
    Author.objects.filter(slug__in=SAMPLE_AUTHORS, contents__isnull=True, series__isnull=True).delete()
    Topic.objects.filter(contents__isnull=True).delete()
    return count


def _publish_at(value, index):
    if not value:
        return timezone.now() - timedelta(minutes=index)
    try:
        if "T" in str(value):
            dt = datetime.fromisoformat(str(value))
        else:
            dt = datetime.combine(datetime.fromisoformat(str(value)).date(), time(18, 0))
    except ValueError as exc:
        raise ValueError(f"publish_date '{value}' si tarehe sahihi (tumia YYYY-MM-DD)") from exc
    return timezone.make_aware(dt) if timezone.is_naive(dt) else dt


def load(data, *, replace_samples=False, dry_run=False):
    """Import a parsed JSON document. Returns a Report; nothing is saved on dry_run or errors."""
    report = Report()
    if isinstance(data, list):
        data = {"contents": data}
    if not isinstance(data, dict):
        report.errors.append("Faili lazima liwe JSON object yenye 'contents' (au orodha ya jumbe).")
        return report

    categories = {c.slug: c for c in Category.objects.all()}
    try:
        with transaction.atomic():
            if replace_samples:
                report.removed_samples = remove_samples()

            authors = {}
            for i, a in enumerate(data.get("authors") or []):
                key = a.get("key") or slugify(a.get("name", ""))
                if not a.get("name"):
                    report.errors.append(f"authors[{i}]: 'name' inakosekana")
                    continue
                obj, created = Author.objects.update_or_create(
                    slug=slugify(key)[:200],
                    defaults={"name": a["name"], "title": a.get("title", ""), "bio": a.get("bio", "")},
                )
                authors[key] = obj
                report.authors += created

            def author_for(key, where):
                if not key:
                    return None
                if key in authors:
                    return authors[key]
                found = Author.objects.filter(slug=slugify(key)).first() or Author.objects.filter(name__iexact=key).first()
                if found is None:
                    found = Author.objects.create(name=key)
                    report.authors += 1
                    report.warnings.append(f"{where}: mwandishi '{key}' ameundwa (hakuwa kwenye 'authors')")
                authors[key] = found
                return found

            series = {}
            for i, s in enumerate(data.get("series") or []):
                where = f"series[{i}] {s.get('title', '')}"
                cat = categories.get(s.get("category"))
                if not s.get("title") or cat is None:
                    report.errors.append(f"{where}: 'title' na 'category' sahihi vinahitajika (category: {s.get('category')})")
                    continue
                level = s.get("access_level", "free")
                if level not in LEVELS:
                    report.errors.append(f"{where}: access_level '{level}' si sahihi ({', '.join(sorted(LEVELS))})")
                    continue
                slug = slugify(s.get("slug") or s["title"])[:200]
                obj, created = Series.objects.update_or_create(
                    slug=slug,
                    defaults={
                        "title": s["title"], "category": cat, "description": s.get("description", ""),
                        "access_level": level, "order": s.get("order", i),
                        "author": author_for(s.get("author"), where),
                        "status": PublishStatus.PUBLISHED,
                    },
                )
                series[s.get("slug") or s["title"]] = obj
                series[slug] = obj
                report.series += created

            for i, c in enumerate(data.get("contents") or []):
                title = c.get("title", "").strip()
                where = f"contents[{i}] {title or '(bila kichwa)'}"
                problems = []
                cat = categories.get(c.get("category"))
                if not title:
                    problems.append("'title' inakosekana")
                if cat is None:
                    problems.append(f"category '{c.get('category')}' haipo")
                if not (c.get("body_html") or c.get("body")):
                    problems.append("'body_html' inakosekana")
                kind = c.get("kind", "devotional")
                if kind not in KINDS:
                    problems.append(f"kind '{kind}' si sahihi ({', '.join(sorted(KINDS))})")
                level = c.get("access_level", "free")
                if level not in LEVELS:
                    problems.append(f"access_level '{level}' si sahihi")
                ser = None
                if c.get("series"):
                    ser = series.get(c["series"]) or Series.objects.filter(slug=slugify(c["series"])).first()
                    if ser is None:
                        problems.append(f"series '{c['series']}' haipo kwenye faili wala kwenye mfumo")
                try:
                    publish_at = _publish_at(c.get("publish_date"), i)
                except ValueError as e:
                    problems.append(str(e))
                if problems:
                    report.errors.append(f"{where}: " + "; ".join(problems))
                    continue

                slug = slugify(c.get("slug") or title)[:200]
                obj, created = Content.objects.update_or_create(
                    slug=slug,
                    defaults={
                        "title": title,
                        "kind": kind,
                        "category": cat,
                        "series": ser,
                        "order_in_series": c.get("order_in_series", 0) or 0,
                        "author": author_for(c.get("author"), where),
                        "scripture_reference": c.get("scripture_reference", ""),
                        "scripture_text": c.get("scripture_text", ""),
                        "summary": c.get("summary", ""),
                        "body": clean_html(c.get("body_html") or c.get("body")),
                        "application": clean_html(c.get("application", "")),
                        "prayer": clean_html(c.get("prayer", "")),
                        "access_level": level,
                        "share_excerpt": c.get("share_excerpt") or c.get("summary", ""),
                        "is_featured": bool(c.get("featured", False)),
                        "status": PublishStatus.PUBLISHED if c.get("publish", True) else PublishStatus.DRAFT,
                        "publish_at": publish_at,
                    },
                )
                topics = [Topic.objects.get_or_create(name=t.strip()[:80])[0] for t in (c.get("topics") or []) if str(t).strip()]
                obj.topics.set(topics)
                if created:
                    report.created += 1
                else:
                    report.updated += 1

            if report.errors or dry_run:
                raise _Rollback()
    except _Rollback:
        pass
    return report


class _Rollback(Exception):
    pass


def load_text(text, **kwargs):
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        r = Report()
        r.errors.append(f"JSON si sahihi (mstari {e.lineno}, safu {e.colno}): {e.msg}")
        return r
    return load(data, **kwargs)
