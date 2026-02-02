"""
Django settings for tact_api project.
"""
from pathlib import Path
import os
import dj_database_url
from cryptography.fernet import Fernet
from django.core.management.utils import get_random_secret_key

# --- ADD THIS SECTION ---
from dotenv import load_dotenv # Import
load_dotenv()                  # Load variables from .env
# ------------------------

# Build paths inside the project...
BASE_DIR = Path(__file__).resolve().parent.parent
# ==========================================
# 1. SECURITY & ENVIRONMENT
# ==========================================

# SECURITY WARNING: keep the secret key used in production secret!
# If SECRET_KEY is not in env, generates a random one (safe fallback)
SECRET_KEY = os.environ.get('SECRET_KEY', get_random_secret_key())

# SECURITY WARNING: don't run with debug turned on in production!
# On Railway, set DJANGO_DEBUG=False. Locally it defaults to True.
DEBUG = os.environ.get('DJANGO_DEBUG', 'True') == 'True'

ALLOWED_HOSTS = [
    'localhost',
    '127.0.0.1',
    '.railway.app',           # Covers all railway subdomains
    'tact-api.up.railway.app',
    'tact-3c612.web.app',     # Your Frontend
    'dankie-website.web.app', # Your Website
    '*',                      # CAUTION: Only strictly for testing mobile connections
]

# ==================================================================================
# 2. CORS & CSRF (Flutter Connection)
# ==================================================================================

CORS_ALLOW_ALL_ORIGINS = True  # Useful for mobile apps during dev, strictly restrict in high-security

# Trusted Origins for CSRF (Must include http/https scheme)
CSRF_TRUSTED_ORIGINS = [
    'https://tact-api.up.railway.app',
    'https://tact-3c612.web.app',
    'https://dankie-website.web.app',
    'http://localhost',
    'http://127.0.0.1',
]

# ==========================================
# 3. INSTALLED APPS & MIDDLEWARE
# ==========================================

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'api',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware', 
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'tact_api.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'tact_api.wsgi.application'

# ==========================================
# 4. DATABASE (Critical for Railway)
# ==========================================

# If DATABASE_URL is set (Railway), use Postgres. Otherwise SQLite (Local).
DATABASES = {
    'default': dj_database_url.config(
        default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}",
        conn_max_age=600,
        conn_health_checks=True,
    )
}

# ==========================================
# 5. PASSWORD VALIDATION
# ==========================================

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# ==========================================
# 6. INTERNATIONALIZATION
# ==========================================

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# ==========================================
# 7. STATIC FILES (WhiteNoise Configuration)
# ==========================================

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Use WhiteNoise to serve static files in production
if not DEBUG:
    STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# ==========================================
# 8. EMAIL CONFIGURATION (Gmail)
# ========================================================================


EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True 
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER') 
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD') 

# =========================================================================
# 9. ENCRYPTION & FIREBASE 
# =========================================================================
 
ENCRYPTION_KEY = os.environ.get('FERNET_KEY')
 
if not ENCRYPTION_KEY:
    print("⚠️ WARNING: FERNET_KEY not found in env. Using temporary key (DATA LOSS RISK).")
    ENCRYPTION_KEY = Fernet.generate_key()
else:
    # Ensure it's bytes
    if isinstance(ENCRYPTION_KEY, str):
        ENCRYPTION_KEY = ENCRYPTION_KEY.encode()
         

try:
    Fernet(ENCRYPTION_KEY)
except Exception as e:
    print(f"⚠️ FATAL SECURITY ERROR: Invalid FERNET_KEY: {e}")

# Firebase
FIREBASE_SERVICE_ACCOUNT_JSON = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')

FIREBASE_STORAGE_BUCKET = 'tact-3c612.firebasestorage.app'

# =======================================================================
# 10. PRODUCTION HEADERS
# =======================================================================

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

if not DEBUG:
    
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_BROWSER_XSS_FILTER = True
    X_FRAME_OPTIONS = 'DENY'







