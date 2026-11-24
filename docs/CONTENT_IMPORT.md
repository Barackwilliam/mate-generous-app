# Bulk content import (JSON)

Admin → **Contents** → **Pakia maudhui (JSON)**. Upload one or more `.json` files.

- Tick **"Kagua tu"** first: it checks the files and saves nothing.
- Tick **"Futa maudhui ya sampuli kwanza"** once to remove the 16 built-in samples (your own content is never touched).
- Items are matched by `slug`: uploading a corrected file updates them, it does not duplicate.
- If a file has any error, nothing from that file is saved, and every problem is listed by item title.

Command line (local/dev): `python manage.py import_content file1.json file2.json [--replace-samples] [--dry-run]`

## Format

```json
{
  "authors": [
    {"key": "mch-mate-generous", "name": "Mch. Mate Generous", "title": "Mchungaji", "bio": "..."}
  ],
  "series": [
    {"slug": "zaburi-za-usiku", "title": "Zaburi za Usiku", "category": "kesha-la-usiku",
     "author": "mch-mate-generous", "access_level": "free", "description": "...", "order": 1}
  ],
  "contents": [
    {
      "slug": "kilio-hudumu-usiku-mmoja",
      "title": "Kilio Hudumu Usiku Mmoja",
      "category": "kesha-la-usiku",
      "series": "zaburi-za-usiku",
      "order_in_series": 1,
      "author": "mch-mate-generous",
      "kind": "devotional",
      "scripture_reference": "Zaburi 30:5",
      "scripture_text": "Kilio huweza kuja kukaa usiku, lakini asubuhi huwa furaha.",
      "summary": "One or two lines for cards and search.",
      "body_html": "<p>...</p><h2>...</h2><p>...</p><blockquote>...</blockquote>",
      "application": "<p>...</p>",
      "prayer": "<p>...</p>",
      "access_level": "free",
      "share_excerpt": "The only text users may share.",
      "topics": ["Tumaini", "Kusubiri"],
      "publish_date": "2026-12-01",
      "featured": false
    }
  ]
}
```

| Field | Allowed values |
| --- | --- |
| `category` | `kesha-la-usiku`, `asubuhi-ya-tumaini`, `weary-souls`, `marriage-family`, `bible-study`, `unabii`, `sermons`, `leadership`, `prayer`, `books`, `courses` (or any category the admin created) |
| `kind` | `devotional`, `article`, `sermon`, `audio`, `book_chapter` |
| `access_level` | `free`, `subscriber`, `premium` |
| `publish_date` | `YYYY-MM-DD` (published at 18:00 Dar es Salaam; a future date schedules it) |
| HTML tags kept | `p h2 h3 blockquote strong em b i ul ol li br hr`; everything else is removed. Plain text with blank lines between paragraphs also works |

Required per item: `title`, `category`, `body_html`. Everything else is optional. `series` and `author` may refer to entries in the same file or ones already in the system.
