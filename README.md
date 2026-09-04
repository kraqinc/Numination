# Numination — Flutter Android

This repository is the Android Flutter client migrated from the supplied Numination Kotlin/Compose project.

## Scope

- Flutter 3.47+ / Dart 3.12+
- Material 3 UI with Riverpod state management
- Supabase Auth: Google OAuth, GitHub OAuth, email OTP/magic-link flow
- Same Vercel/Next.js backend contract as the supplied Android app
- Dashboard, projects, file explorer/editor, AI chat, AI agent actions, terminal, credits, memory, notifications, profile, settings and owner console
- Local app workspace cache backed by `path_provider` + `shared_preferences`
- Android deep-link callback: `numination://auth`
- Release signing wired to `android/keystore/numination-release.jks`
- GitHub Actions builds debug/release APKs and can restore the keystore from repository secrets

## Backend separation

The backend is **not included** in this project. Keep the Next.js/Prisma backend in its own private repository/deployment. The Flutter app only receives its HTTPS base URL through `API_BASE_URL`.

## Environment

Copy `.env.example` to `.env` and fill in the Supabase publishable key and Google OAuth client ID. Do not commit `.env`.

`SUPABASE_PUBLISHABLE_KEY` is a client-side key and must still be protected by correct Supabase RLS/policies. Never put `DATABASE_URL`, `DIRECT_URL`, `JWT_SECRET`, `GEMINI_API_KEY`, PayPal secrets or Supabase service-role credentials in this app.

## Git

The delivered archive intentionally contains **no `.git` directory**. Initialize your own repository and remote after extracting it.

## Backend contract carried over from the original client

- `GET/POST /projects`
- `GET/POST /projects/:projectId/files`
- `PUT/DELETE /projects/:projectId/files/:fileId`
- `POST /ai/chat`
- `POST /ai/agent/execute`
- `GET /credits`
- `GET /credits/history`
- `POST /credits/recharge`
- `GET/POST /memory`
- `GET/POST /notifications`
- `GET /activity`
- `GET/POST /owner`
- `GET /meta/app-version`

All authenticated requests send `Authorization: Bearer <Supabase access token>`.

## Supabase redirect setup

The Android manifest registers `numination://auth`. Add that exact URI to the Supabase Auth redirect allow-list and use it as the OAuth/email redirect. Supabase's current Flutter SDK uses PKCE by default for flows involving deep links; the project therefore does not manually pass access tokens through the custom scheme.

## CI secrets

Create these GitHub Actions secrets in the new client repository:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_AUTH_GOOGLE_CLIENT_ID` (kept for compatibility/configuration)
- `API_BASE_URL`
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The workflow does not clone, build, or expose the private backend repository.
