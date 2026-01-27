#!/usr/bin/env bash

# =============================================================================
# Health Check Script
# =============================================================================
# Verifica salute di tutti i servizi
#
# Usage: ./health-check.sh <environment>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "$SCRIPT_DIR"

source scripts/lib/logger.sh
source scripts/lib/env-loader.sh

# =============================================================================
# FUNZIONI
# =============================================================================

# Check singolo servizio
check_service() {
    local service_name=$1
    local check_command=$2

    echo -n "  ${service_name}... "

    if eval "$check_command" > /dev/null 2>&1; then
        echo -e "${COLOR_GREEN}✓ OK${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_RED}✗ FAIL${COLOR_RESET}"
        return 1
    fi
}

# Health check n8n
check_n8n() {
    log_info "n8n Services:"

    local all_ok=0

    # n8n Postgres
    check_service "n8n-postgres" \
        "docker exec ${PROJECT_NAME}-n8n-postgres pg_isready -U ${N8N_DB_POSTGRESDB_USER}" || all_ok=1

    # n8n App
    check_service "n8n-app" \
        "curl -s -f -u ${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD} http://localhost:${N8N_PORT}/healthz" || all_ok=1

    echo ""
    return $all_ok
}

# Health check Supabase
check_supabase() {
    log_info "Supabase Services:"

    local all_ok=0

    # Postgres
    check_service "postgres" \
        "docker exec ${PROJECT_NAME}-supabase-db pg_isready -U ${POSTGRES_USER}" || all_ok=1

    # Kong (API Gateway)
    check_service "kong" \
        "curl -s -f http://localhost:${SUPABASE_KONG_HTTP_PORT}/auth/v1/health" || all_ok=1

    # Studio
    check_service "studio" \
        "curl -s -f http://localhost:${SUPABASE_STUDIO_PORT}" || all_ok=1

    # Auth
    check_service "auth" \
        "docker exec ${PROJECT_NAME}-supabase-auth wget -q -O- http://localhost:9999/health" || all_ok=1

    # REST API
    check_service "rest" \
        "curl -s -f http://localhost:${SUPABASE_KONG_HTTP_PORT}/rest/v1/" || all_ok=1

    # Storage
    check_service "storage" \
        "curl -s -f http://localhost:${SUPABASE_KONG_HTTP_PORT}/storage/v1/healthcheck" || all_ok=1

    echo ""
    return $all_ok
}

# Health check Backup
check_backup() {
    log_info "Backup Service:"

    local all_ok=0

    check_service "backup" \
        "docker ps --filter name=${PROJECT_NAME}-backup --filter status=running --format '{{.Names}}'" || all_ok=1

    echo ""
    return $all_ok
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: $0 <environment>"
        exit 1
    fi

    local environment=$1

    log_header "Health Check - $environment"

    # Carica env
    load_env "$environment" || exit 1

    local overall_status=0

    # Check servizi abilitati
    if is_profile_enabled "n8n"; then
        check_n8n || overall_status=1
    fi

    if is_profile_enabled "supabase"; then
        check_supabase || overall_status=1
    fi

    if is_profile_enabled "backup"; then
        check_backup || overall_status=1
    fi

    # Riepilogo finale
    if [[ $overall_status -eq 0 ]]; then
        log_success "Tutti i servizi sono operativi"
    else
        log_error "Alcuni servizi hanno problemi"
        exit 1
    fi
}

main "$@"
