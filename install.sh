#!/usr/bin/env bash

# =============================================================================
# LOCAL PLATFORM KIT - Installation Wizard
# =============================================================================
# Setup guidato per installazione e configurazione iniziale
#
# Usage: ./install.sh [environment]
#   environment: dev, staging, prod (default: dev)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source scripts/lib/logger.sh

# =============================================================================
# FUNZIONI DI UTILITA'
# =============================================================================

print_banner() {
    clear
    echo -e "${COLOR_CYAN}${COLOR_BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║          LOCAL PLATFORM KIT - INSTALLER              ║
║                                                       ║
║  Self-hosted Supabase + n8n + Backup System         ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${COLOR_RESET}"
    echo ""
}

# Genera stringa random per secrets
generate_secret() {
    local length=${1:-32}
    openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
}

# Genera JWT secret
generate_jwt_secret() {
    openssl rand -base64 32
}

# =============================================================================
# STEP 1: SELEZIONE AMBIENTE
# =============================================================================

select_environment() {
    log_header "Step 1: Selezione Ambiente"

    if [[ -n "${1:-}" ]]; then
        ENVIRONMENT=$1
        log_info "Ambiente selezionato da parametro: $ENVIRONMENT"
    else
        echo "Seleziona l'ambiente da configurare:"
        echo "  1) dev       - Sviluppo locale"
        echo "  2) staging   - Pre-produzione"
        echo "  3) prod      - Produzione"
        echo ""
        echo -n "Scelta [1]: "
        read -r env_choice
        env_choice=${env_choice:-1}

        case $env_choice in
            1) ENVIRONMENT="dev" ;;
            2) ENVIRONMENT="staging" ;;
            3) ENVIRONMENT="prod" ;;
            *) log_error "Scelta non valida"; exit 1 ;;
        esac
    fi

    ENV_DIR="environments/${ENVIRONMENT}"
    ENV_FILE="${ENV_DIR}/.env"

    log_success "Ambiente: $ENVIRONMENT"
}

# =============================================================================
# STEP 2: SELEZIONE SERVIZI
# =============================================================================

select_services() {
    log_header "Step 2: Selezione Servizi"

    echo "Quali servizi vuoi installare?"
    echo "  1) Solo n8n"
    echo "  2) Solo Supabase"
    echo "  3) n8n + Supabase"
    echo "  4) Solo backup"
    echo "  5) Tutto (n8n + Supabase + backup)"
    echo ""
    echo -n "Scelta [5]: "
    if ! read -r service_choice; then
        service_choice=5
    fi
    service_choice=${service_choice:-5}

    case $service_choice in
        1)
            INSTALL_N8N=true
            INSTALL_SUPABASE=false
            INSTALL_BACKUP=false
            ;;
        2)
            INSTALL_N8N=false
            INSTALL_SUPABASE=true
            INSTALL_BACKUP=false
            ;;
        3)
            INSTALL_N8N=true
            INSTALL_SUPABASE=true
            INSTALL_BACKUP=false
            ;;
        4)
            INSTALL_N8N=false
            INSTALL_SUPABASE=false
            INSTALL_BACKUP=true
            ;;
        5)
            INSTALL_N8N=true
            INSTALL_SUPABASE=true
            INSTALL_BACKUP=true
            ;;
        *)
            log_error "Scelta non valida"
            exit 1
            ;;
    esac

    log_success "Servizi selezionati:"
    [[ $INSTALL_N8N == true ]] && log_info "  - n8n"
    [[ $INSTALL_SUPABASE == true ]] && log_info "  - Supabase"
    [[ $INSTALL_BACKUP == true ]] && log_info "  - Backup"
}

# =============================================================================
# STEP 3: CONFIGURAZIONE BACKUP
# =============================================================================

configure_backup() {
    if [[ $INSTALL_BACKUP == false ]]; then
        BACKUP_ENABLED=false
        BACKUP_GDRIVE_ENABLED=false
        return 0
    fi

    log_header "Step 3: Configurazione Backup"

    if confirm "Abilitare backup automatici?"; then
        BACKUP_ENABLED=true

        echo ""
        echo -n "Schedule cron [0 2 * * *]: "
        read -r backup_schedule
        BACKUP_SCHEDULE=${backup_schedule:-"0 2 * * *"}

        echo -n "Retention in giorni [30]: "
        read -r backup_retention
        BACKUP_RETENTION_DAYS=${backup_retention:-30}

        echo ""
        if confirm "Abilitare backup su Google Drive?"; then
            BACKUP_GDRIVE_ENABLED=true
            log_warning "Dovrai configurare rclone manualmente dopo l'installazione"
            log_info "Esegui: rclone config"
        else
            BACKUP_GDRIVE_ENABLED=false
        fi

        log_success "Backup configurato"
    else
        BACKUP_ENABLED=false
        BACKUP_GDRIVE_ENABLED=false
    fi
}

# =============================================================================
# STEP 4: GENERAZIONE SECRETS
# =============================================================================

generate_secrets() {
    log_header "Step 4: Generazione Secrets"

    log_info "Generazione secrets sicuri..."

    # N8N
    if [[ $INSTALL_N8N == true ]]; then
        N8N_ENCRYPTION_KEY=$(generate_secret 32)
        N8N_DB_PASSWORD=$(generate_secret 32)
        log_debug "N8N secrets generati"
    fi

    # Supabase
    if [[ $INSTALL_SUPABASE == true ]]; then
        POSTGRES_PASSWORD=$(generate_secret 32)
        JWT_SECRET=$(generate_jwt_secret)
        log_debug "Supabase secrets generati"
    fi

    log_success "Secrets generati"
}

# =============================================================================
# STEP 5: CONFIGURAZIONE PORTE
# =============================================================================

configure_ports() {
    log_header "Step 5: Configurazione Porte"

    case $ENVIRONMENT in
        dev)
            N8N_PORT=5678
            SUPABASE_KONG_HTTP_PORT=8000
            SUPABASE_STUDIO_PORT=3000
            POSTGRES_PORT=5432
            ;;
        staging)
            N8N_PORT=5679
            SUPABASE_KONG_HTTP_PORT=8001
            SUPABASE_STUDIO_PORT=3001
            POSTGRES_PORT=5433
            ;;
        prod)
            N8N_PORT=5680
            SUPABASE_KONG_HTTP_PORT=8002
            SUPABASE_STUDIO_PORT=3002
            POSTGRES_PORT=5434
            ;;
    esac

    log_info "Porte configurate per ambiente $ENVIRONMENT:"
    [[ $INSTALL_N8N == true ]] && log_info "  - n8n: $N8N_PORT"
    if [[ $INSTALL_SUPABASE == true ]]; then
        log_info "  - Supabase Kong: $SUPABASE_KONG_HTTP_PORT"
        log_info "  - Supabase Studio: $SUPABASE_STUDIO_PORT"
        log_info "  - Postgres: $POSTGRES_PORT"
    fi
}

# =============================================================================
# STEP 6: CREAZIONE FILE .env
# =============================================================================

create_env_file() {
    log_header "Step 6: Creazione File di Configurazione"

    mkdir -p "$ENV_DIR"

    if [[ -f "$ENV_FILE" ]]; then
        log_warning "Backup vecchia configurazione: ${ENV_FILE}.backup"
        cp "$ENV_FILE" "${ENV_FILE}.backup"
        log_info "File .env esistente sarà sovrascritto"
    fi

    log_info "Creazione: $ENV_FILE"

    cat > "$ENV_FILE" << EOF
# =============================================================================
# LOCAL PLATFORM KIT - Environment: ${ENVIRONMENT}
# =============================================================================
# Generato automaticamente da install.sh il $(date)

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
ENVIRONMENT=${ENVIRONMENT}
PROJECT_NAME=platform-${ENVIRONMENT}

# -----------------------------------------------------------------------------
# N8N Configuration
# -----------------------------------------------------------------------------
N8N_ENABLED=${INSTALL_N8N}
N8N_PORT=${N8N_PORT}
N8N_HOST=0.0.0.0
N8N_PROTOCOL=http
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=changeme123

N8N_DB_TYPE=postgresdb
N8N_DB_POSTGRESDB_HOST=n8n-postgres
N8N_DB_POSTGRESDB_PORT=5432
N8N_DB_POSTGRESDB_DATABASE=n8n
N8N_DB_POSTGRESDB_USER=n8n
N8N_DB_POSTGRESDB_PASSWORD=${N8N_DB_PASSWORD:-changeme}

N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-changeme}

# -----------------------------------------------------------------------------
# SUPABASE Configuration
# -----------------------------------------------------------------------------
SUPABASE_ENABLED=${INSTALL_SUPABASE}
SUPABASE_PUBLIC_URL=http://localhost:${SUPABASE_KONG_HTTP_PORT}

POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-changeme}
POSTGRES_PORT=${POSTGRES_PORT}
POSTGRES_DB=postgres
POSTGRES_USER=postgres

JWT_SECRET=${JWT_SECRET:-changeme}
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU

SUPABASE_KONG_HTTP_PORT=${SUPABASE_KONG_HTTP_PORT}
SUPABASE_KONG_HTTPS_PORT=8443
SUPABASE_STUDIO_PORT=${SUPABASE_STUDIO_PORT}
SUPABASE_INBUCKET_PORT=9000

SUPABASE_STORAGE_BACKEND=file
SUPABASE_STORAGE_FILE_PATH=/var/lib/storage

# -----------------------------------------------------------------------------
# BACKUP Configuration
# -----------------------------------------------------------------------------
BACKUP_ENABLED=${BACKUP_ENABLED}
BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 2 * * *}"
BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}
BACKUP_LOCAL_PATH=./backups

BACKUP_GDRIVE_ENABLED=${BACKUP_GDRIVE_ENABLED}
BACKUP_GDRIVE_REMOTE_NAME=gdrive
BACKUP_GDRIVE_FOLDER=/platform-backups

# -----------------------------------------------------------------------------
# NETWORK
# -----------------------------------------------------------------------------
NETWORK_NAME=platform-network-${ENVIRONMENT}

# -----------------------------------------------------------------------------
# DOCKER VOLUMES
# -----------------------------------------------------------------------------
VOLUME_PREFIX=platform-${ENVIRONMENT}
EOF

    log_success "File .env creato: $ENV_FILE"
}

# =============================================================================
# STEP 7: INIZIALIZZAZIONE STATE FILE
# =============================================================================

init_state() {
    log_header "Step 7: Inizializzazione State File"

    source scripts/lib/state-manager.sh

    if ! check_state_dependencies; then
        log_error "Dipendenze mancanti"
        exit 1
    fi

    init_state_file "$ENVIRONMENT"
    log_success "State file inizializzato"
}

# =============================================================================
# STEP 8: CREAZIONE DIRECTORY
# =============================================================================

create_directories() {
    log_header "Step 8: Creazione Directory"

    local dirs=(
        "docker/n8n/data"
        "docker/supabase/volumes/db/init"
        "docker/supabase/volumes/kong"
        "docker/backup"
        "migrations/supabase"
        "migrations/n8n/workflows"
        "migrations/n8n/credentials"
        "backups/n8n"
        "backups/supabase"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_debug "Creata: $dir"
        fi
    done

    log_success "Directory create"
}

# =============================================================================
# STEP 9: CONFIGURAZIONE KONG (Supabase)
# =============================================================================

setup_kong() {
    if [[ $INSTALL_SUPABASE == false ]]; then
        return 0
    fi

    log_header "Step 9: Configurazione Kong"

    local kong_file="docker/supabase/volumes/kong/kong.yml"

    if [[ -f "$kong_file" ]]; then
        log_info "Kong già configurato"
        return 0
    fi

    log_info "Creazione configurazione Kong..."

    cat > "$kong_file" << 'EOF'
_format_version: "2.1"

services:
  - name: auth
    url: http://supabase-auth:9999
    routes:
      - name: auth-route
        paths:
          - /auth/v1
    plugins:
      - name: cors

  - name: rest
    url: http://supabase-rest:3000
    routes:
      - name: rest-route
        paths:
          - /rest/v1
    plugins:
      - name: cors

  - name: realtime
    url: http://supabase-realtime:4000
    routes:
      - name: realtime-route
        paths:
          - /realtime/v1
    plugins:
      - name: cors

  - name: storage
    url: http://supabase-storage:5000
    routes:
      - name: storage-route
        paths:
          - /storage/v1
    plugins:
      - name: cors
EOF

    log_success "Kong configurato"
}

# =============================================================================
# STEP 10: RIEPILOGO E AVVIO
# =============================================================================

show_summary() {
    log_header "Riepilogo Installazione"

    echo "Ambiente: $ENVIRONMENT"
    echo ""
    echo "Servizi:"
    [[ $INSTALL_N8N == true ]] && echo "  ✓ n8n (porta: $N8N_PORT)"
    [[ $INSTALL_SUPABASE == true ]] && echo "  ✓ Supabase (porta: $SUPABASE_KONG_HTTP_PORT)"
    [[ $BACKUP_ENABLED == true ]] && echo "  ✓ Backup"
    echo ""
    echo "Configurazione: $ENV_FILE"
    echo ""
}

offer_start() {
    log_header "Installazione Completata"

    log_success "Setup completato con successo!"
    echo ""
    log_info "Per avviare i servizi:"
    echo ""
    echo "  ./platform.sh up $ENVIRONMENT"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    print_banner

    # Check prerequisites
    if ! command -v docker &> /dev/null; then
        log_error "Docker non trovato. Installa Docker prima di continuare."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq non trovato. Installa jq: sudo apt-get install jq"
        exit 1
    fi

    # Run installation steps
    select_environment "${1:-}"
    select_services
    configure_backup
    generate_secrets
    configure_ports
    create_env_file
    init_state
    create_directories
    setup_kong

    # Summary and start
    show_summary
    offer_start

    log_success "Installazione completata!"
}

# Run main
main "$@"
