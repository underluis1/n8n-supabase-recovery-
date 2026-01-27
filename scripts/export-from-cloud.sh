#!/usr/bin/env bash

# =============================================================================
# Export from Cloud - Supabase & n8n
# =============================================================================
# Script per esportare dati da ambienti cloud
#
# Usage: ./export-from-cloud.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
cd "$SCRIPT_DIR"

source scripts/lib/logger.sh

# =============================================================================
# CONFIGURAZIONE
# =============================================================================

log_header "Export da Cloud - Configuration"

echo "Questo script ti aiuterà a esportare dati da Supabase e n8n cloud"
echo ""

# Supabase Cloud
log_info "Supabase Cloud Configuration:"
echo -n "Supabase Project ID: "
read -r SUPABASE_PROJECT_ID

echo -n "Supabase Database Password: "
read -rs SUPABASE_DB_PASSWORD
echo ""

echo -n "Database Host (es: db.xxx.supabase.co): "
read -r SUPABASE_DB_HOST

# n8n Cloud
log_info "n8n Cloud Configuration:"
echo -n "n8n URL (es: https://xxx.app.n8n.cloud): "
read -r N8N_URL

echo -n "n8n API Key: "
read -rs N8N_API_KEY
echo ""

# Output directory
EXPORT_DIR="exports/cloud-dev-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$EXPORT_DIR"

log_success "Configuration complete"
log_info "Export directory: $EXPORT_DIR"

# =============================================================================
# EXPORT SUPABASE
# =============================================================================

export_supabase() {
    log_header "Export Supabase Database"

    local output_file="${EXPORT_DIR}/supabase_cloud_dev.sql"

    log_info "Connessione a Supabase Cloud..."
    log_info "Host: $SUPABASE_DB_HOST"

    # Export schema + dati
    log_info "Export in corso (può richiedere tempo)..."

    PGPASSWORD="$SUPABASE_DB_PASSWORD" pg_dump \
        -h "$SUPABASE_DB_HOST" \
        -p 5432 \
        -U postgres \
        -d postgres \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        --exclude-schema=_analytics \
        --exclude-schema=_realtime \
        --exclude-table-data='storage.objects' \
        > "$output_file"

    if [[ $? -eq 0 ]]; then
        # Comprimi
        gzip "$output_file"
        local size=$(du -h "${output_file}.gz" | cut -f1)
        log_success "Supabase export completato: ${output_file}.gz ($size)"
        echo "$output_file.gz"
    else
        log_error "Export Supabase fallito"
        return 1
    fi
}

# =============================================================================
# EXPORT N8N WORKFLOWS
# =============================================================================

export_n8n_workflows() {
    log_header "Export n8n Workflows"

    local workflows_dir="${EXPORT_DIR}/n8n-workflows"
    mkdir -p "$workflows_dir"

    log_info "Recupero lista workflows..."

    # Get all workflows
    local workflows=$(curl -s \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        "${N8N_URL}/api/v1/workflows")

    if [[ $? -ne 0 ]]; then
        log_error "Errore connessione a n8n cloud"
        return 1
    fi

    # Count workflows
    local count=$(echo "$workflows" | jq -r '.data | length')
    log_info "Trovati $count workflows"

    # Export each workflow
    local i=0
    echo "$workflows" | jq -c '.data[]' | while read -r workflow; do
        ((i++))
        local workflow_id=$(echo "$workflow" | jq -r '.id')
        local workflow_name=$(echo "$workflow" | jq -r '.name' | sed 's/[^a-zA-Z0-9_-]/_/g')

        log_info "[$i/$count] Export: $workflow_name (ID: $workflow_id)"

        # Get full workflow details
        local workflow_full=$(curl -s \
            -H "X-N8N-API-KEY: $N8N_API_KEY" \
            "${N8N_URL}/api/v1/workflows/${workflow_id}")

        # Format numero per ordinamento
        local num=$(printf "%03d" $i)

        # Save
        echo "$workflow_full" | jq '.' > "${workflows_dir}/${num}_${workflow_name}.json"
    done

    local exported_count=$(ls -1 "$workflows_dir" | wc -l)
    log_success "Workflows esportati: $exported_count"
    echo "$workflows_dir"
}

# =============================================================================
# EXPORT N8N DATABASE (ALTERNATIVA)
# =============================================================================

export_n8n_database() {
    log_header "Export n8n Database (Alternative Method)"

    log_warning "Questa opzione richiede accesso diretto al database n8n cloud"
    if ! confirm "Hai accesso al database n8n? (es: n8n self-hosted su cloud)"; then
        log_info "Skip export database n8n"
        return 0
    fi

    echo -n "n8n Database Host: "
    read -r N8N_DB_HOST

    echo -n "n8n Database User: "
    read -r N8N_DB_USER

    echo -n "n8n Database Password: "
    read -rs N8N_DB_PASSWORD
    echo ""

    echo -n "n8n Database Name: "
    read -r N8N_DB_NAME

    local output_file="${EXPORT_DIR}/n8n_cloud_dev.sql"

    log_info "Export database n8n..."

    PGPASSWORD="$N8N_DB_PASSWORD" pg_dump \
        -h "$N8N_DB_HOST" \
        -U "$N8N_DB_USER" \
        -d "$N8N_DB_NAME" \
        --clean \
        --if-exists \
        --no-owner \
        --no-privileges \
        > "$output_file"

    if [[ $? -eq 0 ]]; then
        gzip "$output_file"
        local size=$(du -h "${output_file}.gz" | cut -f1)
        log_success "n8n database export completato: ${output_file}.gz ($size)"
        echo "$output_file.gz"
    else
        log_error "Export n8n database fallito"
        return 1
    fi
}

# =============================================================================
# CREAZIONE SCRIPT DI IMPORT
# =============================================================================

create_import_scripts() {
    log_header "Creazione Script di Import"

    # Script per staging
    cat > "${EXPORT_DIR}/import-to-staging.sh" << 'EOFSCRIPT'
#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Import in STAGING"
echo "=========================================="
echo ""

EXPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="../../"

cd "$PLATFORM_DIR"

# 1. Setup staging se non esiste
if [[ ! -f "environments/staging/.env" ]]; then
    echo "Setup staging environment..."
    ./install.sh staging
fi

# 2. Avvia servizi
echo "Avvio servizi staging..."
./platform.sh up staging

# 3. Import Supabase
echo ""
echo "Import Supabase database..."
if [[ -f "$EXPORT_DIR"/supabase_cloud_dev.sql.gz ]]; then
    # Copia backup nella directory corretta
    cp "$EXPORT_DIR"/supabase_cloud_dev.sql.gz backups/supabase/

    # Restore
    ./platform.sh restore staging backups/supabase/supabase_cloud_dev.sql.gz
    echo "Supabase import completato"
else
    echo "ATTENZIONE: File Supabase non trovato"
fi

# 4. Import n8n workflows
echo ""
echo "Import n8n workflows..."
if [[ -d "$EXPORT_DIR/n8n-workflows" ]]; then
    # Copia workflows nelle migrazioni
    mkdir -p migrations/n8n/workflows
    cp "$EXPORT_DIR"/n8n-workflows/*.json migrations/n8n/workflows/

    # Applica migrazioni (importerà i workflows)
    ./platform.sh migrate staging
    echo "n8n workflows import completati"
else
    echo "ATTENZIONE: Workflows n8n non trovati"
fi

echo ""
echo "=========================================="
echo "Import staging completato!"
echo "=========================================="
echo ""
echo "Verifica con:"
echo "  ./platform.sh status staging"
echo "  ./platform.sh health staging"
echo ""
echo "Accedi a:"
echo "  n8n: http://localhost:5679"
echo "  Supabase Studio: http://localhost:3001"
EOFSCRIPT

    chmod +x "${EXPORT_DIR}/import-to-staging.sh"

    # Script per prod (identico ma per prod)
    sed 's/staging/prod/g; s/5679/5680/g; s/3001/3002/g' \
        "${EXPORT_DIR}/import-to-staging.sh" \
        > "${EXPORT_DIR}/import-to-prod.sh"

    chmod +x "${EXPORT_DIR}/import-to-prod.sh"

    log_success "Script di import creati"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_header "Export from Cloud - START"

    # Check dependencies
    if ! command -v pg_dump &> /dev/null; then
        log_error "pg_dump non trovato. Installa PostgreSQL client:"
        log_error "  Ubuntu: sudo apt-get install postgresql-client"
        log_error "  macOS: brew install postgresql"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq non trovato. Installa: sudo apt-get install jq"
        exit 1
    fi

    # Export Supabase
    if confirm "Esportare Supabase Cloud?"; then
        export_supabase
    fi

    # Export n8n workflows
    echo ""
    if confirm "Esportare n8n Workflows?"; then
        export_n8n_workflows
    fi

    # Export n8n database (opzionale)
    echo ""
    if confirm "Esportare anche database n8n completo?"; then
        export_n8n_database
    fi

    # Crea script di import
    echo ""
    create_import_scripts

    # Riepilogo
    log_header "Export Completato"
    echo "Directory: $EXPORT_DIR"
    echo ""
    echo "File esportati:"
    ls -lh "$EXPORT_DIR"
    echo ""
    if [[ -d "$EXPORT_DIR/n8n-workflows" ]]; then
        echo "n8n Workflows:"
        ls -1 "$EXPORT_DIR/n8n-workflows" | wc -l | xargs echo "  Total:"
        echo ""
    fi

    log_success "Prossimi passi:"
    echo ""
    echo "1. Copia questa directory su macchina staging:"
    echo "   scp -r $EXPORT_DIR user@staging-server:~/"
    echo ""
    echo "2. Su macchina staging, esegui:"
    echo "   cd ~/$(basename $EXPORT_DIR)"
    echo "   ./import-to-staging.sh"
    echo ""
    echo "3. Ripeti per prod:"
    echo "   scp -r $EXPORT_DIR user@prod-server:~/"
    echo "   ./import-to-prod.sh"
}

main "$@"
