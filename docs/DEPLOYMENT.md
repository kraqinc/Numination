# Numination deployment

## Authentication

Android uses Google Credential Manager to obtain a Google ID token and sends it directly to Supabase Auth. GitHub OAuth and passwordless email return through `numination://auth`. The Numination backend never verifies Google ID tokens or issues a parallel JWT.

Supabase's current Kotlin SDK supports native ID-token sign-in and Android deep-link handling for PKCE/OAuth flows.

## Android build

Required GitHub Actions secrets:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `DATABASE_URL`
- `DIRECT_URL`
- `GEMINI_API_KEY`
- `GOOGLE_SERVICES_JSON` (base64)
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The Supabase URL/publishable key are safe for Android, but using GitHub Secrets keeps the workflow simpler.

## Supabase provider setup

In Supabase Dashboard -> Authentication -> Providers:

- Google: use the Web OAuth client ID and secret from the Numination Google project. Keep nonce verification enabled.
- GitHub: add the GitHub OAuth App credentials.
- Email: enable passwordless email / OTP.

Under Authentication -> URL Configuration, add:

`numination://auth`

Supabase's Android SDK should handle the callback through `handleDeeplinks(intent)`.

## Email delivery with Brevo

For hosted Supabase, SMTP is configured in Supabase Auth settings or through the Supabase Management API; the application's `.env` file is not automatically read by the hosted Auth service. The repository therefore includes `scripts/configure-supabase-smtp.sh`, which reads the same environment variables and calls the documented Management API.

Required env values:

```text
SUPABASE_ACCESS_TOKEN=...
SUPABASE_PROJECT_REF=whxqciwphwgzcshejpty
SUPABASE_SMTP_HOST=smtp-relay.brevo.com
SUPABASE_SMTP_PORT=587
SUPABASE_SMTP_USER=your-brevo-smtp-login
SUPABASE_SMTP_PASSWORD=your-brevo-smtp-key
SUPABASE_SMTP_ADMIN_EMAIL=no-reply@your-domain.example
SUPABASE_SMTP_SENDER_NAME=Numination
```

`SUPABASE_SMTP_PASSWORD` must be a Brevo SMTP key, not a Brevo API key. Port 587 is the recommended Brevo SMTP submission port.

Run once from the repo root after loading the root `.env`:

```bash
set -a
source .env
set +a
./scripts/configure-supabase-smtp.sh
```

For local Supabase CLI, the same variables are referenced by `supabase/config.toml` via `env(...)`.

## Database

The canonical fresh-project schema is `supabase/migrations/20260810000000_numination_schema.sql`. It creates the application tables, the `auth.users -> profiles` trigger, credits initialization and RLS.

If the Supabase project already contains production application tables from the pre-Supabase migration, **do not blindly run a fresh-project migration**. Make a database backup and reconcile the existing schema first.

Prisma remains the server-side data access layer for the Numination API. `prisma generate` runs in CI; schema provisioning is handled explicitly in Supabase SQL.

## Backend auth validation

`backend/src/lib/supabaseAuth.ts` verifies modern asymmetric Supabase access tokens locally against `/auth/v1/.well-known/jwks.json`. For legacy HS256 projects it can optionally fall back to `/auth/v1/user` when `SUPABASE_PUBLISHABLE_KEY` is configured. No service-role key or JWT signing secret is needed.

## Secrets

Never commit `.env*` files, the Android keystore, Google service config, service-role/secret keys, Google client secrets, or SMTP keys. The previous migration archive contained real provider credentials; rotate any credentials that were included in that archive.
