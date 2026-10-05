"""Settings come from the environment. See APP.md for the full list."""

import os
from pathlib import Path
from urllib.parse import urlparse

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get("SECRET_KEY", "dev-only-not-a-secret")
DEBUG = os.environ.get("DEBUG", "0") == "1"
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "*").split(",")
ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
USE_TZ = True
TIME_ZONE = "UTC"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
INSTALLED_APPS = ["django.contrib.contenttypes", "scans"]
MIDDLEWARE = []

if os.environ.get("DATABASE_URL"):
    _db = urlparse(os.environ["DATABASE_URL"])
    _db_settings = {
        "NAME": _db.path.lstrip("/"),
        "USER": _db.username,
        "PASSWORD": _db.password,
        "HOST": _db.hostname,
        "PORT": _db.port or 5432,
    }
else:
    _db_settings = {
        "NAME": os.environ.get("DB_NAME", "scan"),
        "USER": os.environ.get("DB_USER", "scan"),
        "PASSWORD": os.environ.get("DB_PASSWORD", "scan"),
        "HOST": os.environ.get("DB_HOST", "localhost"),
        "PORT": int(os.environ.get("DB_PORT", "5432")),
    }
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "CONN_MAX_AGE": 60,
        "OPTIONS": {"sslmode": os.environ.get("DB_SSLMODE", "prefer")},
        **_db_settings,
    }
}

AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
SCAN_QUEUE_URL = os.environ.get("SCAN_QUEUE_URL", "")
# Large accounts can take up to ~4 minutes to scan.
SCAN_VISIBILITY_TIMEOUT_SECONDS = int(os.environ.get("SCAN_VISIBILITY_TIMEOUT_SECONDS", "300"))
SCAN_SIMULATED_SECONDS = float(os.environ.get("SCAN_SIMULATED_SECONDS", "1.5"))
EXPORTS_BUCKET = os.environ.get("EXPORTS_BUCKET", "")
# The link we email members. Production: https://<bucket>.s3.amazonaws.com
EXPORTS_BASE_URL = os.environ.get("EXPORTS_BASE_URL", f"https://{EXPORTS_BUCKET}.s3.amazonaws.com")
S3_ADDRESSING_STYLE = os.environ.get("S3_ADDRESSING_STYLE", "auto")

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {"json": {"()": "scans.logging.JsonFormatter"}},
    "handlers": {"stdout": {"class": "logging.StreamHandler", "formatter": "json"}},
    "root": {"handlers": ["stdout"], "level": os.environ.get("LOG_LEVEL", "INFO")},
}
