#!/usr/bin/env bash

# =============================================================================
# Restore Script
# =============================================================================
# Ripristina database da backup

set -euo pipefail

# Logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $@" >&2
}

# =============================================================================
# RESTORE FUNCTIONS
# =============================================================================

restore_n8n() {
    local backup_file=$1

    log "Restoring n8n from: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Decomprimi e ripristina
    gunzip -c "$backup_file" | PGPASSWORD="${N8N_DB_PASSWORD}" psql \
        -h "${N8N_DB_HOST}" \
        -p "${N8N_DB_PORT}" \
        -U "${N8N_DB_USER}" \
        -d "${N8N_DB_DATABASE}" \
        -v ON_ERROR_STOP=1 \
        --quiet

    if [[ $? -eq 0 ]]; then
        log "n8n restore completed"
        return 0
    else
        log_error "n8n restore failed"
        return 1
    fi
}

restore_supabase() {
    local backup_file=$1

    log "Restoring Supabase from: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Decomprimi e ripristina
    gunzip -c "$backup_file" | PGPASSWORD="${SUPABASE_DB_PASSWORD}" psql \
        -h "${SUPABASE_DB_HOST}" \
        -p "${SUPABASE_DB_PORT}" \
        -U "${SUPABASE_DB_USER}" \
        -d "${SUPABASE_DB_DATABASE}" \
        -v ON_ERROR_STOP=1 \
        --quiet

    if [[ $? -eq 0 ]]; then
        log "Supabase restore completed"
        return 0
    else
        log_error "Supabase restore failed"
        return 1
    fi
}

# Detect backup type from filename
detect_backup_type() {
    local backup_file=$1

    if [[ "$backup_file" =~ n8n ]]; then
        echo "n8n"
    elif [[ "$backup_file" =~ supabase ]]; then
        echo "supabase"
    else
        echo "unknown"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: $0 <backup_file>"
        exit 1
    fi

    local backup_file=$1

    log "=========================================="
    log "Restore started"
    log "=========================================="

    # Detect tipo di backup
    local backup_type=$(detect_backup_type "$backup_file")

    log "Backup type detected: $backup_type"

    case $backup_type in
        n8n)
            restore_n8n "$backup_file"
            ;;
        supabase)
            restore_supabase "$backup_file"
            ;;
        *)
            log_error "Unknown backup type for file: $backup_file"
            log_error "Filename must contain 'n8n' or 'supabase'"
            exit 1
            ;;
    esac

    local exit_code=$?

    log "=========================================="
    if [[ $exit_code -eq 0 ]]; then
        log "Restore completed successfully"
    else
        log "Restore failed"
    fi
    log "=========================================="

    exit $exit_code
}

main "$@"
