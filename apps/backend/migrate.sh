#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting Medusa database migrations..."

npx medusa db:migrate

echo "✅ Medusa database migrations completed successfully."
