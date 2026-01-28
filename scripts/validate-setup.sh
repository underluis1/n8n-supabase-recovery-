#!/usr/bin/env bash

# =============================================================================
# Validate Setup - Pre-flight Checks
# =============================================================================
# Verifica che il sistema sia configurato correttamente prima dell'avvio
#
# Usage: ./scripts/validate-setup.sh <environment>

set -euo pipefail

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
    echo "Usage: ./scripts/validate-setup.sh <environment>"
    exit 1
fi

ENVIRONMENT=$1

# =============================================================================
# CHECKS
# =============================================================================

log_header "Validazione Setup - ${ENVIRONMENT}"

ERRORS=0
WARNINGS=0

# 1. Check environment file exists
if [[ ! -f "$PROJECT_ROOT/environments/${ENVIRONMENT}/.env" ]]; then
    log_error "✗ File .env non trovato: environments/${ENVIRONMENT}/.env"
    log_info "  Esegui: ./install.sh ${ENVIRONMENT}"
    ERRORS=$((ERRORS + 1))
else
    log_info "✓ File .env trovato"
    source "$PROJECT_ROOT/environments/${ENVIRONMENT}/.env"
fi

# 2. Check Docker
if ! command -v docker &> /dev/null; then
    log_error "✗ Docker non installato"
    ERRORS=$((ERRORS + 1))
else
    log_info "✓ Docker installato"

    if ! docker info &> /dev/null; then
        log_error "✗ Docker daemon non in esecuzione"
        ERRORS=$((ERRORS + 1))
    else
        log_info "✓ Docker daemon attivo"
    fi
fi

# 3. Check Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "✗ Docker Compose non disponibile"
    ERRORS=$((ERRORS + 1))
else
    log_info "✓ Docker Compose disponibile"
fi

# 4. Check init SQL files
if [[ -f "$PROJECT_ROOT/docker/supabase/volumes/db/init/00-init-schemas.sql" ]] && \
   [[ -f "$PROJECT_ROOT/docker/supabase/volumes/db/init/01-init-roles.sql" ]]; then
    log_info "✓ Script SQL di inizializzazione presenti"
else
    log_warning "⚠ Script SQL di inizializzazione mancanti"
    log_info "  Potrebbero essere necessari per l'inizializzazione del database"
    WARNINGS=$((WARNINGS + 1))
fi

# 5. Check N8N data directory permissions (Linux only)
if [[ -d "$PROJECT_ROOT/docker/n8n/data" ]]; then
    if [[ "$(uname)" == "Linux" ]]; then
        local owner_uid=$(stat -c '%u' "$PROJECT_ROOT/docker/n8n/data" 2>/dev/null || echo "0")
        if [[ "$owner_uid" != "1000" ]]; then
            log_warning "⚠ Permessi directory N8N non corretti (owner: $owner_uid, atteso: 1000)"
            log_info "  Verrà corretto automaticamente all'avvio"
            WARNINGS=$((WARNINGS + 1))
        else
            log_info "✓ Permessi directory N8N corretti"
        fi
    fi
fi

# 6. Check porte disponibili
if [[ -n "${N8N_PORT:-}" ]]; then
    if lsof -i :"${N8N_PORT}" &> /dev/null; then
        log_warning "⚠ Porta ${N8N_PORT} (N8N) già in uso"
        WARNINGS=$((WARNINGS + 1))
    else
        log_info "✓ Porta ${N8N_PORT} (N8N) disponibile"
    fi
fi

if [[ -n "${SUPABASE_KONG_HTTP_PORT:-}" ]]; then
    if lsof -i :"${SUPABASE_KONG_HTTP_PORT}" &> /dev/null; then
        log_warning "⚠ Porta ${SUPABASE_KONG_HTTP_PORT} (Supabase API) già in uso"
        WARNINGS=$((WARNINGS + 1))
    else
        log_info "✓ Porta ${SUPABASE_KONG_HTTP_PORT} (Supabase API) disponibile"
    fi
fi

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
log_header "Riepilogo Validazione"

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    log_success "✓ Tutto OK! Sistema pronto per l'avvio"
    echo ""
    log_info "Esegui: ./platform.sh up ${ENVIRONMENT}"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    log_warning "⚠ ${WARNINGS} warning(s) trovati, ma il sistema dovrebbe funzionare"
    echo ""
    log_info "Esegui: ./platform.sh up ${ENVIRONMENT}"
    exit 0
else
    log_error "✗ ${ERRORS} errore(i) critico(i) trovato(i)"
    if [[ $WARNINGS -gt 0 ]]; then
        log_warning "⚠ ${WARNINGS} warning(s) aggiuntivo(i)"
    fi
    echo ""
    log_info "Correggi gli errori prima di avviare i servizi"
    exit 1
fi
