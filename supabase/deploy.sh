#!/bin/bash
# ==============================================================================
# KORTEXIFY SUPABASE DEPLOYMENT & MIGRATION SCRIPT
# ==============================================================================

set -e

echo "=== [KORTEXIFY SUPABASE BACKEND DEPLOYMENT] ==="

# Check if supabase CLI is available
if ! command -v supabase &> /dev/null; then
    echo "[!] Supabase CLI not found globally. Trying npx..."
    SUPABASE_CMD="npx -y supabase"
else
    SUPABASE_CMD="supabase"
fi

echo "Using command: $SUPABASE_CMD"

# If DB URL provided, apply migrations directly via psql / supabase db push
if [ -n "$DATABASE_URL" ]; then
    echo "[+] Applying migrations to remote database: $DATABASE_URL"
    $SUPABASE_CMD db push --db-url "$DATABASE_URL"
else
    echo "[+] Local deployment mode: starting or migrating local Supabase container..."
    $SUPABASE_CMD migration up || echo "[!] Run '$SUPABASE_CMD start' first if running locally."
fi

echo "=== [DEPLOYMENT SCRIPT FINISHED] ==="
