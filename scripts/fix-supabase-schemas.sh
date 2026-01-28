#!/usr/bin/env bash

# =============================================================================
# Fix Supabase Schemas - Manual Schema Initialization
# =============================================================================
# Questo script risolve il problema quando i volumi esistono già e gli script
# di init non sono stati eseguiti automaticamente da PostgreSQL.
#
# Usage: ./scripts/fix-supabase-schemas.sh <environment>

set -euo pipefail

# Get project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

source "$PROJECT_ROOT/scripts/lib/logger.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

if [[ $# -lt 1 ]]; then
    log_error "Specifica l'ambiente: dev, staging, prod"
    echo ""
    echo "Usage: ./scripts/fix-supabase-schemas.sh <environment>"
    exit 1
fi

ENVIRONMENT=$1

# Carica environment
if [[ ! -f "$PROJECT_ROOT/environments/${ENVIRONMENT}/.env" ]]; then
    log_error "File environment non trovato: $PROJECT_ROOT/environments/${ENVIRONMENT}/.env"
    exit 1
fi

source "$PROJECT_ROOT/environments/${ENVIRONMENT}/.env"

CONTAINER_NAME="${PROJECT_NAME}-supabase-db"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"

# =============================================================================
# FUNCTIONS
# =============================================================================

check_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Container ${CONTAINER_NAME} non in esecuzione"
        log_info "Avvia prima i servizi: ./platform.sh up ${ENVIRONMENT}"
        exit 1
    fi
}

execute_sql() {
    local sql_file=$1
    local description=$2

    log_info "${description}..."

    if [[ -f "$sql_file" ]]; then
        docker exec -i -e PGPASSWORD="${POSTGRES_PASSWORD}" "${CONTAINER_NAME}" \
            psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" < "$sql_file"
    else
        log_error "File non trovato: ${sql_file}"
        exit 1
    fi
}

download_and_execute_sql() {
    local url=$1
    local description=$2

    log_info "${description}..."

    curl -s "${url}" | docker exec -i -e PGPASSWORD="${POSTGRES_PASSWORD}" "${CONTAINER_NAME}" \
        psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
}

# =============================================================================
# MAIN
# =============================================================================

log_header "Fix Supabase Schemas - ${ENVIRONMENT}"

# Check container
check_container

# 1. Apply role initialization
execute_sql "$PROJECT_ROOT/docker/supabase/volumes/db/init/01-init-roles.sql" "Creazione ruoli Supabase"

# 2. Apply schema initialization
execute_sql "$PROJECT_ROOT/docker/supabase/volumes/db/init/00-init-schemas.sql" "Creazione schema Supabase"

# 3. Apply Storage migrations
log_info "Download e applicazione migrazioni Storage..."
download_and_execute_sql \
    "https://raw.githubusercontent.com/supabase/storage/master/migrations/tenant/0001-initialmigration.sql" \
    "Storage: 0001-initialmigration"

download_and_execute_sql \
    "https://raw.githubusercontent.com/supabase/storage/master/migrations/tenant/0002-storage-schema.sql" \
    "Storage: 0002-storage-schema"

# 4. Verify schemas
log_info "Verifica schema creati..."
docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" "${CONTAINER_NAME}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "\dn"

log_success "Schema Supabase inizializzati correttamente"

# 5. Restart services
log_info "Riavvio servizi Supabase..."
docker restart "${PROJECT_NAME}-supabase-storage" \
    "${PROJECT_NAME}-supabase-auth" \
    "${PROJECT_NAME}-supabase-realtime" 2>/dev/null || true

log_success "Fix completato!"
echo ""
log_info "Verifica stato con: ./platform.sh status ${ENVIRONMENT}"
