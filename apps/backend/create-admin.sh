#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting Medusa admin user creation..."

if [[ -z "${MEDUSA_ADMIN_EMAIL:-}" ]] || [[ -z "${MEDUSA_ADMIN_PASSWORD:-}" ]]; then
  echo "❌ Error: MEDUSA_ADMIN_EMAIL and MEDUSA_ADMIN_PASSWORD are required." >&2
  exit 1
fi

CREATE_EXIT_CODE=0
CREATE_OUTPUT=$(npx medusa user -e "$MEDUSA_ADMIN_EMAIL" -p "$MEDUSA_ADMIN_PASSWORD" 2>&1) || CREATE_EXIT_CODE=$?

echo "$CREATE_OUTPUT"

if [[ $CREATE_EXIT_CODE -ne 0 ]]; then
  if [[ "$CREATE_OUTPUT" == *"User"*"already exists"* ]]; then
    echo "ℹ️ Admin user already exists."
  else
    echo "❌ Admin creation failed."
    exit $CREATE_EXIT_CODE
  fi
else
  echo "✅ Admin user created successfully."
fi
