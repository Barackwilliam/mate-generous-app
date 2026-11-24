"""Django settings for the Mate Generous App backend.

Everything environment-specific comes from environment variables so the same
code runs locally, in CI and on Render. See .env.example for the full list.
"""

import os
from datetime import timedelta
from pathlib import Path

import dj_database_url
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")


def env_bool(name, default=False):
    return os.environ.get(name, str(default)).lower() in {"1", "true", "yes", "on"}


def env_list(name, default=""):
    return [item.strip() for item in os.environ.get(name, default).split(",") if item.strip()]


DEBUG = env_bool("DJANGO_DEBUG", False)
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "")
if not SECRET_KEY:
    if not DEBUG:
        raise RuntimeError("DJANGO_SECRET_KEY must be set when DEBUG is off.")
    SECRET_KEY = "dev-only-insecure-key"

ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1")
CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")

INSTALLED_APPS = [
    "unfold",
    "unfold.contrib.filters",
    "unfold.contrib.forms",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "django_filters",
    "corsheaders",
    "apps.audit",
    "apps.accounts",
    "apps.catalog",
    "apps.library",
    "apps.subscriptions",
    "apps.payments",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# Production uses Supabase Postgres through its *Session pooler* URL (IPv4,
# port 5432). Render's free plan cannot reach Supabase's IPv6-only direct host.
DATABASES = {
    "default": dj_database_url.config(
        default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}",
        conn_max_age=600,
        conn_health_checks=True,
        ssl_require=os.environ.get("DATABASE_URL", "").startswith("postgres") and not DEBUG,
    )
}

AUTH_USER_MODEL = "accounts.User"
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "sw"
TIME_ZONE = "Africa/Dar_es_Salaam"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"
# --- Media storage: Supabase Storage buckets (S3 API) in production --------
# Supabase dashboard → Storage → S3 Connection gives the endpoint, region and
# access keys. Create two buckets: one PUBLIC (images), one PRIVATE (audio).
SUPABASE_S3_ENDPOINT = os.environ.get("SUPABASE_S3_ENDPOINT", "")  # https://<ref>.supabase.co/storage/v1/s3
SUPABASE_PUBLIC_BUCKET = os.environ.get("SUPABASE_PUBLIC_BUCKET", "media-public")
SUPABASE_PRIVATE_BUCKET = os.environ.get("SUPABASE_PRIVATE_BUCKET", "media-private")
SIGNED_URL_SECONDS = int(os.environ.get("SIGNED_URL_SECONDS", "3600"))

if SUPABASE_S3_ENDPOINT:
    _s3 = {
        "endpoint_url": SUPABASE_S3_ENDPOINT,
        "region_name": os.environ.get("SUPABASE_S3_REGION", "us-east-1"),
        "access_key": os.environ.get("SUPABASE_S3_ACCESS_KEY_ID", ""),
        "secret_key": os.environ.get("SUPABASE_S3_SECRET_ACCESS_KEY", ""),
        "signature_version": "s3v4",
        "addressing_style": "path",
        "file_overwrite": False,
        "default_acl": None,
    }
    _project_host = SUPABASE_S3_ENDPOINT.split("://", 1)[-1].split("/", 1)[0]
    _public_storage = {
        "BACKEND": "storages.backends.s3.S3Storage",
        "OPTIONS": {
            **_s3,
            "bucket_name": SUPABASE_PUBLIC_BUCKET,
            "querystring_auth": False,
            # Public objects are served at /storage/v1/object/public/<bucket>/<key>
            "custom_domain": f"{_project_host}/storage/v1/object/public/{SUPABASE_PUBLIC_BUCKET}",
        },
    }
    _private_storage = {
        "BACKEND": "storages.backends.s3.S3Storage",
        "OPTIONS": {**_s3, "bucket_name": SUPABASE_PRIVATE_BUCKET, "querystring_auth": True,
                    "querystring_expire": SIGNED_URL_SECONDS},
    }
else:
    _public_storage = {"BACKEND": "django.core.files.storage.FileSystemStorage",
                       "OPTIONS": {"location": BASE_DIR / "media" / "public", "base_url": "/media/public/"}}
    _private_storage = {"BACKEND": "django.core.files.storage.FileSystemStorage",
                        "OPTIONS": {"location": BASE_DIR / "media" / "private", "base_url": "/media/private/"}}

STORAGES = {
    "default": _public_storage,
    "public": _public_storage,
    "private": _private_storage,
    "staticfiles": {
        "BACKEND": (
            "django.contrib.staticfiles.storage.StaticFilesStorage"
            if DEBUG
            else "whitenoise.storage.CompressedManifestStaticFilesStorage"
        )
    },
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticatedOrReadOnly",
    ],
    "DEFAULT_FILTER_BACKENDS": ["django_filters.rest_framework.DjangoFilterBackend"],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
        "rest_framework.throttling.ScopedRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {"anon": "60/min", "user": "240/min", "auth": "10/min", "payments": "20/min"},
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=30),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    "ROTATE_REFRESH_TOKENS": True,
}

CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS")

# Public web page that shared excerpts link back to, e.g. https://mategenerous.app
SHARE_BASE_URL = os.environ.get("SHARE_BASE_URL", "https://example.com")

# Payment gateway. "sandbox" simulates payments for development and tests;
# the real provider is plugged in once it is chosen (see docs/PAYMENTS.md).
PAYMENT_GATEWAY = os.environ.get("PAYMENT_GATEWAY", "sandbox")
PAYMENT_CALLBACK_SECRET = os.environ.get("PAYMENT_CALLBACK_SECRET", "")
if PAYMENT_GATEWAY == "sandbox" and not DEBUG and not env_bool("ALLOW_SANDBOX_PAYMENTS"):
    raise RuntimeError("The sandbox payment gateway must not run in production.")

if not DEBUG:
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
    SECURE_SSL_REDIRECT = env_bool("DJANGO_SECURE_SSL_REDIRECT", True)
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 60 * 60 * 24 * 30
    SECURE_CONTENT_TYPE_NOSNIFF = True

# Email (password reset codes). Brevo's free SMTP works well: smtp-relay.brevo.com:587.
# Without EMAIL_HOST, emails are printed to the log instead of sent.
EMAIL_HOST = os.environ.get("EMAIL_HOST", "")
EMAIL_PORT = int(os.environ.get("EMAIL_PORT", "587"))
EMAIL_HOST_USER = os.environ.get("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.environ.get("EMAIL_HOST_PASSWORD", "")
EMAIL_USE_TLS = env_bool("EMAIL_USE_TLS", True)
EMAIL_TIMEOUT = 15
EMAIL_BACKEND = (
    "django.core.mail.backends.smtp.EmailBackend" if EMAIL_HOST else "django.core.mail.backends.console.EmailBackend"
)
DEFAULT_FROM_EMAIL = os.environ.get("DEFAULT_FROM_EMAIL", "Mate Generous <no-reply@example.com>")

UNFOLD = {
    "SITE_TITLE": "Mate Generous Admin",
    "SITE_HEADER": "Mate Generous",
    "SITE_SYMBOL": "menu_book",
    "SHOW_HISTORY": True,
}

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
