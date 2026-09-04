# Numination backend contract

The Flutter client is intentionally decoupled from the Next.js/Prisma backend. Keep the backend in its own private repository.

Authenticated HTTP requests use:

`Authorization: Bearer <Supabase access token>`

Configured base URL:

`API_BASE_URL=https://backend-one-livid-77.vercel.app/api`

## Routes carried over from the supplied Kotlin client

`GET /projects`
`POST /projects`
`GET /projects/:projectId/files`
`POST /projects/:projectId/files`
`PUT /projects/:projectId/files/:fileId`
`DELETE /projects/:projectId/files/:fileId`
`POST /ai/chat`
`POST /ai/agent/execute`
`GET /credits`
`GET /credits/history`
`POST /credits/recharge`
`GET /memory`
`POST /memory`
`GET /notifications`
`POST /notifications` with `mark_all_read` or `mark_read` + `id`
`GET /activity`
`GET /owner?view=stats`
`GET /owner?view=users`
`GET /owner?view=audit-logs`
`GET /owner?view=pending-recharges`
`POST /owner` for `approve`, `reject`, and `adjust-credits`
`GET /auth/me`
`GET /meta/app-version`
