#!/usr/bin/env bash

# =============================================================================
# Supabase Migration Script
# =============================================================================
# Applica migrazioni SQL in ordine versionato
#
# Usage: ./migrate-supabase.sh <environment>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "$SCRIPT_DIR"

source scripts/lib/logger.sh
source scripts/lib/env-loader.sh
source scripts/lib/state-manager.sh

# =============================================================================
# FUNZIONI
# =============================================================================

# Ottieni lista file di migrazione ordinati
get_migration_files() {
    local migration_dir="migrations/supabase"

    if [[ ! -d "$migration_dir" ]]; then
        log_warning "Directory migrazioni non trovata: $migration_dir"
        return 0
    fi

    # Lista file SQL ordinati numericamente
    find "$migration_dir" -name "*.sql" -type f | sort -V
}

# Estrai nome migrazione da path
get_migration_name() {
    local file_path=$1
    basename "$file_path" .sql
}

# Applica singola migrazione
apply_migration() {
    local environment=$1
    local migration_file=$2
    local migration_name=$(get_migration_name "$migration_file")

    log_info "Applicazione: $migration_name"

    # Verifica se già applicata
    if is_migration_applied "$environment" "supabase" "$migration_name"; then
        log_debug "Migrazione già applicata: $migration_name"
        return 0
    fi

    # Leggi contenuto SQL
    local sql_content
    sql_content=$(<"$migration_file")

    # Ottieni nome container Postgres
    local pg_container="${PROJECT_NAME}-supabase-db"

    # Verifica che container sia running
    if ! docker ps --format '{{.Names}}' | grep -q "^${pg_container}$"; then
        log_error "Container Postgres non in esecuzione: $pg_container"
        log_info "Avvia prima i servizi: ./platform.sh up $environment"
        return 1
    fi

    # Applica migrazione
    log_debug "Esecuzione SQL nel container: $pg_container"

    echo "$sql_content" | docker exec -i "$pg_container" \
        psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -v ON_ERROR_STOP=1 \
        --quiet

    if [[ $? -eq 0 ]]; then
        # Registra migrazione applicata
        mark_migration_applied "$environment" "supabase" "$migration_name"
        log_success "Migrazione applicata: $migration_name"
        return 0
    else
        log_error "Errore durante applicazione migrazione: $migration_name"
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

    log_header "Migrazioni Supabase - $environment"

    # Carica env
    load_env "$environment" || exit 1

    # Verifica che Supabase sia abilitato
    if ! is_profile_enabled "supabase"; then
        log_warning "Supabase non abilitato per questo ambiente"
        exit 0
    fi

    # Init state
    init_state_file "$environment"

    # Ottieni migrazioni
    local migration_files=($(get_migration_files))

    if [[ ${#migration_files[@]} -eq 0 ]]; then
        log_info "Nessuna migrazione da applicare"
        exit 0
    fi

    log_info "Trovate ${#migration_files[@]} migrazioni"

    # Applica migrazioni in ordine
    local applied=0
    local skipped=0
    local failed=0

    for migration_file in "${migration_files[@]}"; do
        local migration_name=$(get_migration_name "$migration_file")

        if is_migration_applied "$environment" "supabase" "$migration_name"; then
            log_debug "Skip (già applicata): $migration_name"
            ((skipped++))
            continue
        fi

        if apply_migration "$environment" "$migration_file"; then
            ((applied++))
        else
            ((failed++))
            log_error "Migrazione fallita: $migration_name"
            log_error "Arresto processo di migrazione"
            exit 1
        fi
    done

    # Riepilogo
    echo ""
    log_header "Riepilogo Migrazioni Supabase"
    echo "Applicate: $applied"
    echo "Skipped: $skipped"
    echo "Fallite: $failed"

    if [[ $failed -gt 0 ]]; then
        log_error "Alcune migrazioni sono fallite"
        exit 1
    else
        log_success "Tutte le migrazioni applicate con successo"
    fi
}

main "$@"
