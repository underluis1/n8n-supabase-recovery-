#!/usr/bin/env bash

# =============================================================================
# Backup Script
# =============================================================================
# Esegue backup di Postgres per n8n e Supabase

set -euo pipefail

# Variabili
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_LOCAL_PATH:-/backups}"
ENVIRONMENT="${ENVIRONMENT:-unknown}"

# Logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $@" >&2
}

# =============================================================================
# BACKUP N8N
# =============================================================================

backup_n8n() {
    if [[ "${N8N_ENABLED:-false}" != "true" ]]; then
        log "n8n backup skipped (not enabled)"
        return 0
    fi

    log "Starting n8n backup..."

    local backup_file="${BACKUP_DIR}/n8n/n8n_${ENVIRONMENT}_${TIMESTAMP}.sql.gz"
    mkdir -p "$(dirname "$backup_file")"

    # Dump database
    PGPASSWORD="${N8N_DB_PASSWORD}" pg_dump \
        -h "${N8N_DB_HOST}" \
        -p "${N8N_DB_PORT}" \
        -U "${N8N_DB_USER}" \
        -d "${N8N_DB_DATABASE}" \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        | gzip > "$backup_file"

    if [[ $? -eq 0 ]]; then
        local size=$(du -h "$backup_file" | cut -f1)
        log "n8n backup completed: $backup_file ($size)"
        echo "$backup_file"
    else
        log_error "n8n backup failed"
        return 1
    fi
}

# =============================================================================
# BACKUP SUPABASE
# =============================================================================

backup_supabase() {
    if [[ "${SUPABASE_ENABLED:-false}" != "true" ]]; then
        log "Supabase backup skipped (not enabled)"
        return 0
    fi

    log "Starting Supabase backup..."

    local backup_file="${BACKUP_DIR}/supabase/supabase_${ENVIRONMENT}_${TIMESTAMP}.sql.gz"
    mkdir -p "$(dirname "$backup_file")"

    # Dump database (excluding postgres system databases)
    PGPASSWORD="${SUPABASE_DB_PASSWORD}" pg_dump \
        -h "${SUPABASE_DB_HOST}" \
        -p "${SUPABASE_DB_PORT}" \
        -U "${SUPABASE_DB_USER}" \
        -d "${SUPABASE_DB_DATABASE}" \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        | gzip > "$backup_file"

    if [[ $? -eq 0 ]]; then
        local size=$(du -h "$backup_file" | cut -f1)
        log "Supabase backup completed: $backup_file ($size)"
        echo "$backup_file"
    else
        log_error "Supabase backup failed"
        return 1
    fi
}

# =============================================================================
# UPLOAD TO GOOGLE DRIVE
# =============================================================================

upload_to_gdrive() {
    local backup_file=$1

    if [[ "${BACKUP_GDRIVE_ENABLED:-false}" != "true" ]]; then
        log "Google Drive upload skipped (not enabled)"
        return 0
    fi

    log "Uploading to Google Drive: $(basename $backup_file)"

    rclone copy \
        "$backup_file" \
        "${BACKUP_GDRIVE_REMOTE_NAME}:${BACKUP_GDRIVE_FOLDER}/${ENVIRONMENT}/" \
        --progress

    if [[ $? -eq 0 ]]; then
        log "Upload completed: $(basename $backup_file)"
    else
        log_error "Upload failed: $(basename $backup_file)"
        return 1
    fi
}

# =============================================================================
# CLEANUP OLD BACKUPS
# =============================================================================

cleanup_old_backups() {
    local retention_days="${BACKUP_RETENTION_DAYS:-30}"

    log "Cleaning up backups older than ${retention_days} days..."

    # Local cleanup
    find "${BACKUP_DIR}" -type f -name "*.sql.gz" -mtime +${retention_days} -delete

    # Google Drive cleanup (se abilitato)
    if [[ "${BACKUP_GDRIVE_ENABLED:-false}" == "true" ]]; then
        log "Cleaning up Google Drive backups..."
        # rclone delete con age filter
        rclone delete \
            "${BACKUP_GDRIVE_REMOTE_NAME}:${BACKUP_GDRIVE_FOLDER}/${ENVIRONMENT}/" \
            --min-age ${retention_days}d
    fi

    log "Cleanup completed"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log "=========================================="
    log "Backup started - Environment: ${ENVIRONMENT}"
    log "=========================================="

    local backup_files=()
    local failed=0

    # Backup n8n
    if [[ "${N8N_ENABLED:-false}" == "true" ]]; then
        if n8n_file=$(backup_n8n); then
            backup_files+=("$n8n_file")
        else
            ((failed++))
        fi
    fi

    # Backup Supabase
    if [[ "${SUPABASE_ENABLED:-false}" == "true" ]]; then
        if supabase_file=$(backup_supabase); then
            backup_files+=("$supabase_file")
        else
            ((failed++))
        fi
    fi

    # Upload to Google Drive
    for backup_file in "${backup_files[@]}"; do
        upload_to_gdrive "$backup_file" || ((failed++))
    done

    # Cleanup old backups
    cleanup_old_backups

    # Summary
    log "=========================================="
    log "Backup completed"
    log "Files created: ${#backup_files[@]}"
    log "Failed operations: ${failed}"
    log "=========================================="

    if [[ $failed -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
