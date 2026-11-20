"""Where uploaded media lives.

- "public" holds cover images and author photos: anyone may load them.
- "private" holds audio (and later video): the app only ever gets a signed,
  short-lived link after the backend checks the listener may play it.

In production both are Supabase Storage buckets reached through its S3 API
(settings.py). Locally and in tests they fall back to the media folder.
Callables keep migrations independent of the environment.
"""

from django.core.files.storage import storages


def public_storage():
    return storages["public"]


def private_storage():
    return storages["private"]
