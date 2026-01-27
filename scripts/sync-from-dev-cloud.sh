#!/usr/bin/env bash

# =============================================================================
# Sync from Dev Cloud - Extract Migrations
# =============================================================================
# Script per estrarre migrazioni da dev cloud e aggiungerle al repository
#
# Usage: ./sync-from-dev-cloud.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "$SCRIPT_DIR"

source scripts/lib/logger.sh

# =============================================================================
# CONFIGURATION
# =============================================================================

CONFIG_FILE=".dev-cloud-config"

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Carico configurazione esistente..."
        source "$CONFIG_FILE"
    else
        log_info "Prima configurazione..."

        echo ""
        log_header "Configurazione Supabase Cloud Dev"
        echo -n "Supabase DB Host (es: db.xxx.supabase.co): "
        read -r SUPABASE_HOST

        echo -n "Supabase DB Password: "
        read -rs SUPABASE_PASSWORD
        echo ""

        echo ""
        log_header "Configurazione n8n Cloud Dev"
        echo -n "n8n URL (es: https://xxx.app.n8n.cloud): "
        read -r N8N_URL

        echo -n "n8n API Key: "
        read -rs N8N_API_KEY
        echo ""

        # Salva config (escludendo password)
        cat > "$CONFIG_FILE" << EOF
# Dev Cloud Configuration
SUPABASE_HOST="${SUPABASE_HOST}"
N8N_URL="${N8N_URL}"
EOF

        log_success "Configurazione salvata in $CONFIG_FILE"
        log_warning "NOTA: Password/API Key non salvate (per sicurezza)"

        # Aggiungi a .gitignore
        if ! grep -q "$CONFIG_FILE" .gitignore 2>/dev/null; then
            echo "$CONFIG_FILE" >> .gitignore
            log_info "Aggiunto $CONFIG_FILE a .gitignore"
        fi
    fi
}

# =============================================================================
# SUPABASE: Genera nuova migrazione da diff
# =============================================================================

generate_supabase_migration() {
    log_header "Supabase Migration Generation"

    echo "Questo genererà una nuova migrazione SQL basata sulle modifiche in dev cloud"
    echo ""

    # Chiedi nome migrazione
    echo -n "Nome migrazione (es: add_payments_table): "
    read -r migration_name

    # Trova prossimo numero
    local last_num=$(ls -1 migrations/supabase/*.sql 2>/dev/null | \
        tail -1 | \
        grep -oP '^\d+' || echo "000")
    local next_num=$(printf "%03d" $((10#$last_num + 1)))

    local migration_file="migrations/supabase/${next_num}_${migration_name}.sql"

    log_info "Creazione: $migration_file"

    # Opzioni per generare migrazione
    echo ""
    echo "Come vuoi generare la migrazione?"
    echo "  1) Schema dump completo (tutto il database)"
    echo "  2) Schema diff (solo modifiche - richiede schema precedente)"
    echo "  3) Scrivo SQL manualmente (apre editor)"
    echo ""
    echo -n "Scelta [3]: "
    read -r choice
    choice=${choice:-3}

    case $choice in
        1)
            log_info "Export schema completo..."

            PGPASSWORD="$SUPABASE_PASSWORD" pg_dump \
                -h "$SUPABASE_HOST" \
                -p 5432 \
                -U postgres \
                -d postgres \
                --schema-only \
                --no-owner \
                --no-privileges \
                --schema=public \
                --schema=app \
                > "$migration_file"

            log_success "Schema esportato"
            ;;

        2)
            log_warning "Schema diff richiede setup più complesso"
            log_info "Usa Supabase CLI per diff automatico:"
            echo ""
            echo "  supabase db diff --linked > $migration_file"
            echo ""
            log_info "Per ora, apro editor per SQL manuale..."

            cat > "$migration_file" << 'EOF'
-- =============================================================================
-- Migration: CHANGE_NAME
-- Description: Add description here
-- =============================================================================

SET search_path TO app, public;

-- Add your SQL here
EOF
            ${EDITOR:-nano} "$migration_file"
            ;;

        3)
            log_info "Creazione template migrazione..."

            cat > "$migration_file" << EOF
-- =============================================================================
-- Migration: ${next_num}_${migration_name}
-- Description: TODO - Add description
-- Created: $(date +%Y-%m-%d)
-- =============================================================================

SET search_path TO app, public;

-- =============================================================================
-- TABLES
-- =============================================================================

-- Example:
-- CREATE TABLE IF NOT EXISTS app.${migration_name} (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     created_at TIMESTAMPTZ DEFAULT NOW()
-- );

-- =============================================================================
-- INDEXES
-- =============================================================================

-- CREATE INDEX IF NOT EXISTS idx_${migration_name}_field ON app.${migration_name}(field);

-- =============================================================================
-- COMMENTS
-- =============================================================================

-- COMMENT ON TABLE app.${migration_name} IS 'Description';
EOF

            log_success "Template creato"
            log_info "Aprendo editor..."
            ${EDITOR:-nano} "$migration_file"
            ;;
    esac

    # Verifica SQL valido
    if [[ -s "$migration_file" ]]; then
        log_success "Migrazione creata: $migration_file"
        echo ""
        log_info "Preview:"
        head -20 "$migration_file"
        echo ""

        if confirm "Migrazione OK?"; then
            log_success "Pronto per commit!"
            echo "$migration_file"
        else
            log_warning "Modifica manualmente: $migration_file"
            ${EDITOR:-nano} "$migration_file"
        fi
    else
        log_error "Migrazione vuota, eliminata"
        rm -f "$migration_file"
        return 1
    fi
}

# =============================================================================
# N8N: Export workflows modificati
# =============================================================================

sync_n8n_workflows() {
    log_header "n8n Workflows Sync"

    echo "Opzioni:"
    echo "  1) Sync tutti i workflows (sovrascrive esistenti)"
    echo "  2) Export singolo workflow"
    echo "  3) Export solo nuovi workflows"
    echo ""
    echo -n "Scelta [1]: "
    read -r choice
    choice=${choice:-1}

    case $choice in
        1)
            sync_all_n8n_workflows
            ;;
        2)
            export_single_n8n_workflow
            ;;
        3)
            sync_new_n8n_workflows
            ;;
    esac
}

sync_all_n8n_workflows() {
    log_info "Sync tutti i workflows..."

    # Get workflows list
    local workflows=$(curl -s \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        "${N8N_URL}/api/v1/workflows")

    if [[ $? -ne 0 ]]; then
        log_error "Errore connessione n8n"
        return 1
    fi

    local count=$(echo "$workflows" | jq -r '.data | length')
    log_info "Trovati $count workflows"

    # Export each
    local i=0
    echo "$workflows" | jq -c '.data[]' | while read -r workflow; do
        ((i++))

        local workflow_id=$(echo "$workflow" | jq -r '.id')
        local workflow_name=$(echo "$workflow" | jq -r '.name' | sed 's/[^a-zA-Z0-9_-]/_/g')

        log_info "[$i/$count] Export: $workflow_name"

        # Get full workflow
        local workflow_full=$(curl -s \
            -H "X-N8N-API-KEY: $N8N_API_KEY" \
            "${N8N_URL}/api/v1/workflows/${workflow_id}")

        # Trova file esistente o crea nuovo
        local existing_file=$(grep -l "\"id\": \"${workflow_id}\"" migrations/n8n/workflows/*.json 2>/dev/null | head -1)

        if [[ -n "$existing_file" ]]; then
            # Update esistente
            echo "$workflow_full" | jq '.' > "$existing_file"
            log_debug "Updated: $existing_file"
        else
            # Nuovo workflow - trova prossimo numero
            local last_num=$(ls -1 migrations/n8n/workflows/*.json 2>/dev/null | \
                tail -1 | \
                grep -oP '^\d+' || echo "000")
            local next_num=$(printf "%03d" $((10#$last_num + 1)))

            local new_file="migrations/n8n/workflows/${next_num}_${workflow_name}.json"
            echo "$workflow_full" | jq '.' > "$new_file"
            log_success "New: $new_file"
        fi
    done

    log_success "Sync workflows completato"
}

export_single_n8n_workflow() {
    log_info "Export singolo workflow..."

    # Lista workflows
    local workflows=$(curl -s \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        "${N8N_URL}/api/v1/workflows")

    echo ""
    echo "Workflows disponibili:"
    echo "$workflows" | jq -r '.data[] | "\(.id): \(.name)"' | nl

    echo ""
    echo -n "ID workflow da esportare: "
    read -r workflow_id

    # Get workflow
    local workflow=$(curl -s \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        "${N8N_URL}/api/v1/workflows/${workflow_id}")

    local workflow_name=$(echo "$workflow" | jq -r '.name' | sed 's/[^a-zA-Z0-9_-]/_/g')

    # Trova prossimo numero
    local last_num=$(ls -1 migrations/n8n/workflows/*.json 2>/dev/null | \
        tail -1 | \
        grep -oP '^\d+' || echo "000")
    local next_num=$(printf "%03d" $((10#$last_num + 1)))

    local file="migrations/n8n/workflows/${next_num}_${workflow_name}.json"

    echo "$workflow" | jq '.' > "$file"

    log_success "Workflow esportato: $file"
}

sync_new_n8n_workflows() {
    log_info "Sync solo nuovi workflows..."

    # Get all workflows
    local workflows=$(curl -s \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        "${N8N_URL}/api/v1/workflows")

    # Check each workflow
    local new_count=0
    echo "$workflows" | jq -c '.data[]' | while read -r workflow; do
        local workflow_id=$(echo "$workflow" | jq -r '.id')
        local workflow_name=$(echo "$workflow" | jq -r '.name' | sed 's/[^a-zA-Z0-9_-]/_/g')

        # Check se esiste già
        if grep -q "\"id\": \"${workflow_id}\"" migrations/n8n/workflows/*.json 2>/dev/null; then
            log_debug "Skip (exists): $workflow_name"
            continue
        fi

        ((new_count++))
        log_info "New workflow: $workflow_name"

        # Export
        local workflow_full=$(curl -s \
            -H "X-N8N-API-KEY: $N8N_API_KEY" \
            "${N8N_URL}/api/v1/workflows/${workflow_id}")

        # Trova numero
        local last_num=$(ls -1 migrations/n8n/workflows/*.json 2>/dev/null | \
            tail -1 | \
            grep -oP '^\d+' || echo "000")
        local next_num=$(printf "%03d" $((10#$last_num + 1)))

        local file="migrations/n8n/workflows/${next_num}_${workflow_name}.json"
        echo "$workflow_full" | jq '.' > "$file"

        log_success "Exported: $file"
    done

    if [[ $new_count -eq 0 ]]; then
        log_info "Nessun nuovo workflow"
    else
        log_success "Esportati $new_count nuovi workflows"
    fi
}

# =============================================================================
# GIT WORKFLOW
# =============================================================================

git_commit_migrations() {
    log_header "Git Commit"

    # Check git status
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_warning "Non è un repository Git"
        if confirm "Inizializzare git repository?"; then
            git init
            log_success "Git repository inizializzato"
        else
            return 0
        fi
    fi

    # Show changes
    echo ""
    log_info "Modifiche da committare:"
    git status --short migrations/

    echo ""
    if ! confirm "Committare le modifiche?"; then
        log_info "Commit annullato"
        return 0
    fi

    # Add migrations
    git add migrations/

    # Commit message
    echo ""
    echo -n "Messaggio commit: "
    read -r commit_msg

    if [[ -z "$commit_msg" ]]; then
        commit_msg="feat: add migrations $(date +%Y-%m-%d)"
    fi

    git commit -m "$commit_msg"

    log_success "Commit creato"

    # Push
    echo ""
    if confirm "Push su remote?"; then
        git push
        log_success "Push completato"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_header "Sync from Dev Cloud"

    # Load config
    load_config

    # Menu
    while true; do
        echo ""
        echo "================================"
        echo "Cosa vuoi fare?"
        echo "================================"
        echo "  1) Crea nuova migrazione Supabase"
        echo "  2) Sync workflows n8n"
        echo "  3) Entrambi"
        echo "  4) Git commit & push"
        echo "  5) Esci"
        echo ""
        echo -n "Scelta: "
        read -r choice

        case $choice in
            1)
                generate_supabase_migration
                ;;
            2)
                sync_n8n_workflows
                ;;
            3)
                generate_supabase_migration
                sync_n8n_workflows
                ;;
            4)
                git_commit_migrations
                ;;
            5)
                log_info "Ciao!"
                exit 0
                ;;
            *)
                log_error "Scelta non valida"
                ;;
        esac
    done
}

main "$@"
