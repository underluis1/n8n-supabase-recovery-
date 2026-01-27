#!/usr/bin/env bash

# =============================================================================
# State Manager - Gestione stato migrazioni
# =============================================================================

# Ottieni path del file di stato
get_state_file() {
    local environment=$1
    echo "environments/${environment}/state.json"
}

# Inizializza file di stato se non esiste
init_state_file() {
    local environment=$1
    local state_file=$(get_state_file "$environment")

    if [[ ! -f "$state_file" ]]; then
        log_info "Inizializzazione state file: $state_file"

        mkdir -p "$(dirname "$state_file")"

        cat > "$state_file" << EOF
{
  "environment": "${environment}",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "last_updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "migrations": {
    "supabase": {
      "applied": [],
      "last_migration": null,
      "last_applied_at": null
    },
    "n8n": {
      "applied": [],
      "last_migration": null,
      "last_applied_at": null
    }
  }
}
EOF
        log_success "State file creato"
    fi
}

# Leggi stato
read_state() {
    local environment=$1
    local state_file=$(get_state_file "$environment")

    if [[ ! -f "$state_file" ]]; then
        log_error "State file non trovato: $state_file"
        return 1
    fi

    cat "$state_file"
}

# Ottieni migrazioni applicate per un tipo
get_applied_migrations() {
    local environment=$1
    local migration_type=$2  # supabase o n8n
    local state_file=$(get_state_file "$environment")

    if [[ ! -f "$state_file" ]]; then
        echo "[]"
        return 0
    fi

    # Usa jq per estrarre array di migrazioni applicate
    jq -r ".migrations.${migration_type}.applied[]" "$state_file" 2>/dev/null || echo ""
}

# Verifica se una migrazione è già stata applicata
is_migration_applied() {
    local environment=$1
    local migration_type=$2
    local migration_name=$3

    local applied=$(get_applied_migrations "$environment" "$migration_type")

    if echo "$applied" | grep -q "^${migration_name}$"; then
        return 0  # Già applicata
    else
        return 1  # Non applicata
    fi
}

# Registra migrazione applicata
mark_migration_applied() {
    local environment=$1
    local migration_type=$2
    local migration_name=$3
    local state_file=$(get_state_file "$environment")

    if [[ ! -f "$state_file" ]]; then
        log_error "State file non trovato: $state_file"
        return 1
    fi

    log_debug "Registrazione migrazione: $migration_name ($migration_type)"

    # Usa jq per aggiornare il JSON
    local tmp_file="${state_file}.tmp"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq \
        --arg type "$migration_type" \
        --arg name "$migration_name" \
        --arg ts "$timestamp" \
        '.migrations[$type].applied += [$name] |
         .migrations[$type].last_migration = $name |
         .migrations[$type].last_applied_at = $ts |
         .last_updated = $ts' \
        "$state_file" > "$tmp_file"

    if [[ $? -eq 0 ]]; then
        mv "$tmp_file" "$state_file"
        log_debug "Migrazione registrata nel state file"
        return 0
    else
        log_error "Errore durante aggiornamento state file"
        rm -f "$tmp_file"
        return 1
    fi
}

# Ottieni ultima migrazione applicata
get_last_migration() {
    local environment=$1
    local migration_type=$2
    local state_file=$(get_state_file "$environment")

    if [[ ! -f "$state_file" ]]; then
        echo ""
        return 0
    fi

    jq -r ".migrations.${migration_type}.last_migration // empty" "$state_file" 2>/dev/null || echo ""
}

# Reset stato migrazioni (per testing o rollback)
reset_migration_state() {
    local environment=$1
    local migration_type=$2
    local state_file=$(get_state_file "$environment")

    if [[ ! -f "$state_file" ]]; then
        log_error "State file non trovato: $state_file"
        return 1
    fi

    log_warning "Reset stato migrazioni per: $migration_type"

    local tmp_file="${state_file}.tmp"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq \
        --arg type "$migration_type" \
        --arg ts "$timestamp" \
        '.migrations[$type].applied = [] |
         .migrations[$type].last_migration = null |
         .migrations[$type].last_applied_at = null |
         .last_updated = $ts' \
        "$state_file" > "$tmp_file"

    if [[ $? -eq 0 ]]; then
        mv "$tmp_file" "$state_file"
        log_success "Stato reset completato"
        return 0
    else
        log_error "Errore durante reset stato"
        rm -f "$tmp_file"
        return 1
    fi
}

# Mostra stato corrente
show_state() {
    local environment=$1
    local state_file=$(get_state_file "$environment")

    if [[ ! -f "$state_file" ]]; then
        log_warning "State file non trovato per ambiente: $environment"
        return 1
    fi

    log_header "Stato Migrazioni - $environment"

    echo "Supabase:"
    local supabase_count=$(jq -r '.migrations.supabase.applied | length' "$state_file")
    local supabase_last=$(jq -r '.migrations.supabase.last_migration // "nessuna"' "$state_file")
    echo "  - Migrazioni applicate: $supabase_count"
    echo "  - Ultima: $supabase_last"
    echo ""

    echo "N8N:"
    local n8n_count=$(jq -r '.migrations.n8n.applied | length' "$state_file")
    local n8n_last=$(jq -r '.migrations.n8n.last_migration // "nessuna"' "$state_file")
    echo "  - Migrazioni applicate: $n8n_count"
    echo "  - Ultima: $n8n_last"
    echo ""

    local last_update=$(jq -r '.last_updated' "$state_file")
    echo "Ultimo aggiornamento: $last_update"
}

# Verifica dipendenze (jq)
check_state_dependencies() {
    if ! command -v jq &> /dev/null; then
        log_error "jq non trovato. Installalo con: sudo apt-get install jq"
        return 1
    fi
    return 0
}

# Export functions
export -f get_state_file
export -f init_state_file
export -f read_state
export -f get_applied_migrations
export -f is_migration_applied
export -f mark_migration_applied
export -f get_last_migration
export -f reset_migration_state
export -f show_state
export -f check_state_dependencies
