#!/usr/bin/env bash

# =============================================================================
# Fix Supabase Storage Schema
# =============================================================================
# Questo script applica le migrazioni necessarie per Supabase Storage
# Eseguire solo se il container supabase-storage è in crash loop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

source scripts/lib/logger.sh

ENVIRONMENT=${1:-dev}
PROJECT_NAME="platform-${ENVIRONMENT}"
DB_CONTAINER="${PROJECT_NAME}-supabase-db"

log_header "Fix Supabase Storage Schema - $ENVIRONMENT"

# Check if database is running
if ! docker ps | grep -q "$DB_CONTAINER"; then
    log_error "Database container $DB_CONTAINER non è in esecuzione"
    log_info "Esegui prima: ./platform.sh up $ENVIRONMENT"
    exit 1
fi

log_info "Applicazione schema storage..."

# Create storage schema tables
docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres << 'SQL'
-- Create storage.objects table
CREATE TABLE IF NOT EXISTS storage.objects (
    id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/')) STORED,
    version text,
    CONSTRAINT objects_pkey PRIMARY KEY (id)
);

-- Create storage.buckets table
CREATE TABLE IF NOT EXISTS storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    CONSTRAINT buckets_pkey PRIMARY KEY (id)
);

-- Grant permissions
GRANT ALL ON storage.objects TO postgres, anon, authenticated, service_role;
GRANT ALL ON storage.buckets TO postgres, anon, authenticated, service_role;

SQL

log_success "Schema storage applicato"

log_info "Riavvio container storage..."
docker restart "${PROJECT_NAME}-supabase-storage" > /dev/null 2>&1

sleep 5

if docker ps | grep "${PROJECT_NAME}-supabase-storage" | grep -q "Up"; then
    log_success "Supabase Storage fixato!"
else
    log_warning "Il container storage potrebbe richiedere più tempo per avviarsi"
    log_info "Controlla i log: docker logs ${PROJECT_NAME}-supabase-storage"
fi
