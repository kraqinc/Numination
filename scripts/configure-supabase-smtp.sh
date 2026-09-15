#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_ACCESS_TOKEN:?Falta SUPABASE_ACCESS_TOKEN}"
: "${SUPABASE_PROJECT_REF:?Falta SUPABASE_PROJECT_REF}"
: "${SUPABASE_SMTP_HOST:?Falta SUPABASE_SMTP_HOST}"
: "${SUPABASE_SMTP_PORT:?Falta SUPABASE_SMTP_PORT}"
: "${SUPABASE_SMTP_USER:?Falta SUPABASE_SMTP_USER}"
: "${SUPABASE_SMTP_PASSWORD:?Falta SUPABASE_SMTP_PASSWORD (usa una clave SMTP de Brevo, NO una API key)}"
: "${SUPABASE_SMTP_ADMIN_EMAIL:?Falta SUPABASE_SMTP_ADMIN_EMAIL}"
: "${SUPABASE_SMTP_SENDER_NAME:?Falta SUPABASE_SMTP_SENDER_NAME}"

python - <<'PY' > /tmp/supabase-auth-email.json
import json, os
payload = {
    "external_email_enabled": True,
    "mailer_secure_email_change_enabled": True,
    "mailer_autoconfirm": False,
    "smtp_admin_email": os.environ["SUPABASE_SMTP_ADMIN_EMAIL"],
    "smtp_host": os.environ["SUPABASE_SMTP_HOST"],
    "smtp_port": int(os.environ["SUPABASE_SMTP_PORT"]),
    "smtp_user": os.environ["SUPABASE_SMTP_USER"],
    "smtp_pass": os.environ["SUPABASE_SMTP_PASSWORD"],
    "smtp_sender_name": os.environ["SUPABASE_SMTP_SENDER_NAME"],
}
print(json.dumps(payload))
PY

curl --fail-with-body --silent --show-error \
  -X PATCH "https://api.supabase.com/v1/projects/${SUPABASE_PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/supabase-auth-email.json

rm -f /tmp/supabase-auth-email.json
echo
echo "Supabase Auth SMTP configurado."
