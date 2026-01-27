#!/usr/bin/env bash

# =============================================================================
# N8N Migration Script
# =============================================================================
# Importa workflows versionati tramite n8n API
#
# Usage: ./migrate-n8n.sh <environment>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "$SCRIPT_DIR"

source scripts/lib/logger.sh
source scripts/lib/env-loader.sh
source scripts/lib/state-manager.sh

# =============================================================================
# FUNZIONI
# =============================================================================

# Ottieni lista workflow files ordinati
get_workflow_files() {
    local workflow_dir="migrations/n8n/workflows"

    if [[ ! -d "$workflow_dir" ]]; then
        log_warning "Directory workflows non trovata: $workflow_dir"
        return 0
    fi

    # Lista file JSON ordinati numericamente
    find "$workflow_dir" -name "*.json" -type f | sort -V
}

# Estrai nome workflow da path
get_workflow_name() {
    local file_path=$1
    basename "$file_path" .json
}

# Attendi che n8n sia pronto
wait_for_n8n() {
    local max_attempts=30
    local attempt=0

    log_info "Attesa avvio n8n..."

    while [[ $attempt -lt $max_attempts ]]; do
        if curl -s -f \
            -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" \
            "http://localhost:${N8N_PORT}/healthz" > /dev/null 2>&1; then
            log_success "n8n pronto"
            return 0
        fi

        ((attempt++))
        sleep 2
    done

    log_error "Timeout: n8n non risponde"
    return 1
}

# Importa singolo workflow
import_workflow() {
    local environment=$1
    local workflow_file=$2
    local workflow_name=$(get_workflow_name "$workflow_file")

    log_info "Import: $workflow_name"

    # Verifica se già importato
    if is_migration_applied "$environment" "n8n" "$workflow_name"; then
        log_debug "Workflow già importato: $workflow_name"
        return 0
    fi

    # Leggi workflow JSON
    local workflow_data
    workflow_data=$(<"$workflow_file")

    # Importa tramite API n8n
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "$workflow_data" \
        "http://localhost:${N8N_PORT}/api/v1/workflows")

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        # Registra workflow importato
        mark_migration_applied "$environment" "n8n" "$workflow_name"
        log_success "Workflow importato: $workflow_name"
        return 0
    else
        log_error "Errore import workflow: $workflow_name (HTTP $http_code)"
        log_debug "Response: $body"
        return 1
    fi
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

    log_header "Migrazioni N8N - $environment"

    # Carica env
    load_env "$environment" || exit 1

    # Verifica che n8n sia abilitato
    if ! is_profile_enabled "n8n"; then
        log_warning "n8n non abilitato per questo ambiente"
        exit 0
    fi

    # Init state
    init_state_file "$environment"

    # Attendi n8n ready
    if ! wait_for_n8n; then
        log_error "n8n non disponibile"
        exit 1
    fi

    # Ottieni workflows
    local workflow_files=($(get_workflow_files))

    if [[ ${#workflow_files[@]} -eq 0 ]]; then
        log_info "Nessun workflow da importare"
        exit 0
    fi

    log_info "Trovati ${#workflow_files[@]} workflows"

    # Importa workflows in ordine
    local imported=0
    local skipped=0
    local failed=0

    for workflow_file in "${workflow_files[@]}"; do
        local workflow_name=$(get_workflow_name "$workflow_file")

        if is_migration_applied "$environment" "n8n" "$workflow_name"; then
            log_debug "Skip (già importato): $workflow_name"
            ((skipped++))
            continue
        fi

        if import_workflow "$environment" "$workflow_file"; then
            ((imported++))
        else
            ((failed++))
            log_warning "Workflow fallito: $workflow_name"
            # Non usciamo subito, continuiamo con altri workflow
        fi
    done

    # Riepilogo
    echo ""
    log_header "Riepilogo Migrazioni N8N"
    echo "Importati: $imported"
    echo "Skipped: $skipped"
    echo "Falliti: $failed"

    if [[ $failed -gt 0 ]]; then
        log_warning "Alcuni workflows sono falliti"
        exit 1
    else
        log_success "Tutti i workflows importati con successo"
    fi
}

main "$@"
