"""

Django settings for SDMS project.

"""



from pathlib import Path

from datetime import timedelta

import os



# ---------------------------------------------------------------------

# BASE DIRECTORY

# ---------------------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent.parent



# ---------------------------------------------------------------------

# ENVIRONMENT CONFIGURATION (.env loader)

# ---------------------------------------------------------------------

def _load_env_file():

    env_file = BASE_DIR / ".env"

    if env_file.exists():

        try:

            with open(env_file, "r", encoding="utf-8") as f:

                for line in f:

                    line = line.strip()

                    if line and not line.startswith("#") and "=" in line:

                        k, v = line.split("=", 1)

                        k = k.strip()

                        v = v.strip().strip("'\"")

                        if k and k not in os.environ:

                            os.environ[k] = v

        except Exception as e:

            print(f"[SETTINGS WARNING] Failed to load .env file: {e}")



_load_env_file()



# ---------------------------------------------------------------------

# SECURITY SETTINGS

# ---------------------------------------------------------------------

SECRET_KEY = "django-insecure-%^xz!o(bd(9pwixqvx-d6t!4(xjke4ogx#*2cvjsvj8oeq7zq#"

DEBUG = True

ALLOWED_HOSTS = ["*"]  # Allow all for local dev



# ---------------------------------------------------------------------

# INSTALLED APPS

# ---------------------------------------------------------------------

INSTALLED_APPS = [

    # Default Django apps

    "django.contrib.admin",

    "django.contrib.auth",

    "django.contrib.contenttypes",

    "django.contrib.sessions",

    "django.contrib.messages",

    "django.contrib.staticfiles",



    # Custom apps

    "userlogin",

    "students",

    "faculty",

    "fees",

    "academics",

    "hod_assignment",

    "subjects",

    "timetable",

    "attendance",

    "ia_assessment",

    "library",

    "grievances",

    "external_results",

    "announcements",
    "corrections",
    "placement",



    # Third-party apps

    "rest_framework",

    "rest_framework_simplejwt",

    "rest_framework_simplejwt.token_blacklist",

    "django_filters",

    "corsheaders",

    "encrypted_model_fields",

]



# ---------------------------------------------------------------------

# MIDDLEWARE

# ---------------------------------------------------------------------

MIDDLEWARE = [

    "django.middleware.security.SecurityMiddleware",



    # CORS must be before CommonMiddleware

    "corsheaders.middleware.CorsMiddleware",

    "django.middleware.common.CommonMiddleware",



    "django.contrib.sessions.middleware.SessionMiddleware",

    "django.middleware.csrf.CsrfViewMiddleware",

    "django.contrib.auth.middleware.AuthenticationMiddleware",

    "django.contrib.messages.middleware.MessageMiddleware",

    "django.middleware.clickjacking.XFrameOptionsMiddleware",

]



ROOT_URLCONF = "SDMS.urls"



# ---------------------------------------------------------------------

# TEMPLATES

# ---------------------------------------------------------------------

TEMPLATES = [

    {

        "BACKEND": "django.template.backends.django.DjangoTemplates",

        "DIRS": [BASE_DIR / "templates"],

        "APP_DIRS": True,

        "OPTIONS": {

            "context_processors": [

                "django.template.context_processors.debug",

                "django.template.context_processors.request",

                "django.contrib.auth.context_processors.auth",

                "django.contrib.messages.context_processors.messages",

            ],

        },

    },

]



WSGI_APPLICATION = "SDMS.wsgi.application"



# ---------------------------------------------------------------------

# DATABASE

# ---------------------------------------------------------------------

DATABASES = {

    "default": {

        "ENGINE": "django.db.backends.postgresql",

        "NAME": "sdms_db",

        "USER": "postgres",

        "PASSWORD": "root",

        "HOST": "localhost",

        "PORT": "5432",

    }

}



# ---------------------------------------------------------------------

# INTERNATIONALIZATION

# ---------------------------------------------------------------------

LANGUAGE_CODE = "en-us"

TIME_ZONE = "Asia/Kolkata"

USE_I18N = True

USE_TZ = True



# ---------------------------------------------------------------------

# STATIC & MEDIA

# ---------------------------------------------------------------------

STATIC_URL = "/static/"

STATIC_ROOT = BASE_DIR / "staticfiles"

STATICFILES_DIRS = [BASE_DIR / "static"]



MEDIA_URL = "/media/"

MEDIA_ROOT = BASE_DIR / "media"



# ---------------------------------------------------------------------

# AUTH

# ---------------------------------------------------------------------

AUTH_USER_MODEL = "userlogin.CustomUser"



# ---------------------------------------------------------------------
# EMAIL SERVICE (DEACTIVATED - IN-APP PASSWORD MANAGEMENT ACTIVE)
# ---------------------------------------------------------------------
# Email delivery has been completely deactivated in SDMS.
# Initial credentials and password resets are managed directly through authorized in-app interfaces.
EMAIL_BACKEND = "django.core.mail.backends.dummy.EmailBackend"

# Frontend Portal URL
FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:51263")



# ---------------------------------------------------------------------

# REST FRAMEWORK (JWT FIXED)

# ---------------------------------------------------------------------

REST_FRAMEWORK = {

    "DEFAULT_AUTHENTICATION_CLASSES": [

        # ✅ Required for Flutter Web JWT Authentication

        "rest_framework_simplejwt.authentication.JWTAuthentication",

    ],

    "DEFAULT_PERMISSION_CLASSES": [

        "rest_framework.permissions.IsAuthenticated",

    ],

    "DEFAULT_FILTER_BACKENDS": [

        "django_filters.rest_framework.DjangoFilterBackend",

        "rest_framework.filters.SearchFilter",

        "rest_framework.filters.OrderingFilter",

    ],

    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",

    "PAGE_SIZE": 10,

}



# ---------------------------------------------------------------------

# JWT CONFIGURATION

# ---------------------------------------------------------------------

SIMPLE_JWT = {

    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=30),

    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),

    "ROTATE_REFRESH_TOKENS": False,

    "BLACKLIST_AFTER_ROTATION": True,

    "AUTH_HEADER_TYPES": ("Bearer",),

}



# ---------------------------------------------------------------------

# FIELD ENCRYPTION

# ---------------------------------------------------------------------

FIELD_ENCRYPTION_KEY = b"4AHnjI4pI41CopQfNriSKYt_ylansFs81CNHCXSYTNc="



# ---------------------------------------------------------------------

# CORS SETTINGS (FULL SUPPORT FOR FLUTTER WEB)

# ---------------------------------------------------------------------

CORS_ALLOW_ALL_ORIGINS = True

CORS_ALLOW_CREDENTIALS = True



CORS_ALLOW_HEADERS = [

    "authorization",

    "content-type",

    "accept",

    "origin",

    "user-agent",

    "x-csrftoken",

    "x-requested-with",

]



# ---------------------------------------------------------------------

# DEFAULT AUTO FIELD

# ---------------------------------------------------------------------

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"



# ---------------------------------------------------------------------

# SECURITY, DATA PROTECTION & SESSION POLICIES

# ---------------------------------------------------------------------

SECURE_SSL_REDIRECT = os.getenv("DJANGO_SECURE_SSL", "False").lower() in ["true", "1"]

SESSION_COOKIE_SECURE = os.getenv("DJANGO_SECURE_SSL", "False").lower() in ["true", "1"]

CSRF_COOKIE_SECURE = os.getenv("DJANGO_SECURE_SSL", "False").lower() in ["true", "1"]

SESSION_COOKIE_HTTPONLY = True

CSRF_COOKIE_HTTPONLY = False



# Session Expiration (30 minutes of inactivity)

SESSION_COOKIE_AGE = 1800

SESSION_SAVE_EVERY_REQUEST = True



# Security Headers

SECURE_BROWSER_XSS_FILTER = True

SECURE_CONTENT_TYPE_NOSNIFF = True

X_FRAME_OPTIONS = "DENY"

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")



# Password Validation Policy

AUTH_PASSWORD_VALIDATORS = [

    {

        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",

    },

    {

        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",

        "OPTIONS": {

            "min_length": 8,

        },

    },

    {

        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",

    },

    {

        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",

    },

]

