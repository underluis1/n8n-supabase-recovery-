#!/usr/bin/env bash

# =============================================================================
# LOCAL PLATFORM KIT - Platform Management Tool
# =============================================================================
# Tool principale per gestione lifecycle della piattaforma
#
# Usage:
#   ./platform.sh <command> <environment> [options]
#
# Commands:
#   up         - Avvia servizi
#   down       - Ferma servizi
#   restart    - Riavvia servizi
#   status     - Mostra stato servizi
#   logs       - Mostra logs
#   migrate    - Applica migrazioni
#   backup     - Esegui backup
#   restore    - Ripristina backup
#   health     - Health check servizi
#   clean      - Pulizia volumi e dati
#
# Examples:
#   ./platform.sh up dev
#   ./platform.sh migrate prod
#   ./platform.sh logs dev n8n

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load libraries
source scripts/lib/logger.sh
source scripts/lib/env-loader.sh
source scripts/lib/state-manager.sh

# =============================================================================
# HELP
# =============================================================================

show_help() {
    cat << EOF
${COLOR_BOLD}Local Platform Kit - Platform Management Tool${COLOR_RESET}

${COLOR_CYAN}USAGE:${COLOR_RESET}
    ./platform.sh <command> <environment> [options]

${COLOR_CYAN}COMMANDS:${COLOR_RESET}
    ${COLOR_GREEN}up${COLOR_RESET}         Avvia servizi per l'ambiente specificato
    ${COLOR_GREEN}down${COLOR_RESET}       Ferma servizi
    ${COLOR_GREEN}restart${COLOR_RESET}    Riavvia servizi
    ${COLOR_GREEN}status${COLOR_RESET}     Mostra stato dei servizi
    ${COLOR_GREEN}logs${COLOR_RESET}       Mostra logs dei servizi
    ${COLOR_GREEN}migrate${COLOR_RESET}    Applica migrazioni pending
    ${COLOR_GREEN}backup${COLOR_RESET}     Esegui backup manuale
    ${COLOR_GREEN}restore${COLOR_RESET}    Ripristina da backup
    ${COLOR_GREEN}health${COLOR_RESET}     Health check di tutti i servizi
    ${COLOR_GREEN}clean${COLOR_RESET}      Pulizia volumi e dati (ATTENZIONE!)
    ${COLOR_GREEN}state${COLOR_RESET}      Mostra stato migrazioni

${COLOR_CYAN}ENVIRONMENTS:${COLOR_RESET}
    dev        Sviluppo locale
    staging    Pre-produzione
    prod       Produzione

${COLOR_CYAN}EXAMPLES:${COLOR_RESET}
    ./platform.sh up dev
    ./platform.sh migrate prod
    ./platform.sh logs dev n8n
    ./platform.sh backup prod
    ./platform.sh status staging
    ./platform.sh health dev

${COLOR_CYAN}NOTES:${COLOR_RESET}
    - Esegui './install.sh' prima del primo utilizzo
    - I servizi avviati dipendono dalla configurazione in .env
    - Usa profiles Docker Compose per controllo granulare

EOF
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Fix permessi N8N per Linux
fix_n8n_permissions() {
    local n8n_data_dir="docker/n8n/data"

    if [[ ! -d "$n8n_data_dir" ]]; then
        mkdir -p "$n8n_data_dir"
    fi

    # Check se giriamo come root o se possiamo fare chown
    if [[ $EUID -eq 0 ]] || command -v sudo &> /dev/null; then
        log_info "Configurazione permessi N8N (UID 1000)..."

        # Verifica owner attuale
        local current_owner=$(stat -c '%u' "$n8n_data_dir" 2>/dev/null || stat -f '%u' "$n8n_data_dir" 2>/dev/null || echo "unknown")

        if [[ "$current_owner" != "1000" ]]; then
            if [[ $EUID -eq 0 ]]; then
                chown -R 1000:1000 "$n8n_data_dir" 2>/dev/null || true
            else
                sudo chown -R 1000:1000 "$n8n_data_dir" 2>/dev/null || {
                    log_warning "Impossibile cambiare permessi. N8N potrebbe fallire."
                    log_info "Esegui manualmente: sudo chown -R 1000:1000 $n8n_data_dir"
                }
            fi
        fi
    fi
}

# Validazione post-avvio
post_start_validation() {
    local environment=$1

    log_info "Validazione servizi..."

    # Aspetta qualche secondo per l'init container
    sleep 3

    # Verifica che i container critici siano running
    local failed=0

    if is_profile_enabled "supabase"; then
        # Check init container completato
        local init_status=$(docker inspect "${PROJECT_NAME}-supabase-db-init" --format='{{.State.Status}}' 2>/dev/null || echo "not_found")

        if [[ "$init_status" == "exited" ]]; then
            local exit_code=$(docker inspect "${PROJECT_NAME}-supabase-db-init" --format='{{.State.ExitCode}}' 2>/dev/null || echo "1")
            if [[ "$exit_code" == "0" ]]; then
                log_info "✓ Database Supabase inizializzato"
            else
                log_warning "⚠ Init container fallito, controlla i log: docker logs ${PROJECT_NAME}-supabase-db-init"
                failed=1
            fi
        fi
    fi

    if [[ $failed -eq 1 ]]; then
        log_warning "Alcuni servizi potrebbero avere problemi. Usa: ./platform.sh status $environment"
    fi
}

# =============================================================================
# COMMAND: UP
# =============================================================================

cmd_up() {
    local environment=$1

    log_header "Avvio Servizi - $environment"

    # Carica env
    load_env "$environment" || exit 1

    # Verifica Docker
    check_docker || exit 1

    # Pre-flight checks e fix automatici
    log_info "Pre-flight checks..."

    # Fix permessi N8N (necessario su Linux)
    if is_profile_enabled "n8n"; then
        fix_n8n_permissions
    fi

    # Ottieni comando compose
    local compose_cmd=$(build_compose_command "$environment" "up" "-d")

    log_info "Profiles attivi: $(get_active_profiles)"
    log_info "Avvio containers..."

    # Esegui comando
    eval "$compose_cmd"

    if [[ $? -eq 0 ]]; then
        log_success "Servizi avviati"

        # Post-start validation
        post_start_validation "$environment"

        echo ""
        log_info "Verifica stato con: ./platform.sh status $environment"

        # Mostra URL di accesso
        show_access_urls "$environment"
    else
        log_error "Errore durante avvio servizi"
        exit 1
    fi
}

# Mostra URL di accesso
show_access_urls() {
    local environment=$1

    log_header "URL di Accesso"

    if is_profile_enabled "n8n"; then
        echo "n8n:"
        echo "  ${COLOR_CYAN}http://localhost:${N8N_PORT}${COLOR_RESET}"
        echo "  User: ${N8N_BASIC_AUTH_USER}"
        echo "  Pass: ${N8N_BASIC_AUTH_PASSWORD}"
        echo ""
    fi

    if is_profile_enabled "supabase"; then
        echo "Supabase:"
        echo "  API: ${COLOR_CYAN}http://localhost:${SUPABASE_KONG_HTTP_PORT}${COLOR_RESET}"
        echo "  Studio: ${COLOR_CYAN}http://localhost:${SUPABASE_STUDIO_PORT}${COLOR_RESET}"
        echo ""
    fi
}

# =============================================================================
# COMMAND: DOWN
# =============================================================================

cmd_down() {
    local environment=$1

    log_header "Arresto Servizi - $environment"

    load_env "$environment" || exit 1
    check_docker || exit 1

    local compose_cmd=$(build_compose_command "$environment" "down")

    log_info "Arresto containers..."
    eval "$compose_cmd"

    log_success "Servizi arrestati"
}

# =============================================================================
# COMMAND: RESTART
# =============================================================================

cmd_restart() {
    local environment=$1

    log_header "Riavvio Servizi - $environment"

    cmd_down "$environment"
    sleep 2
    cmd_up "$environment"

    log_success "Servizi riavviati"
}

# =============================================================================
# COMMAND: STATUS
# =============================================================================

cmd_status() {
    local environment=$1

    log_header "Stato Servizi - $environment"

    load_env "$environment" || exit 1
    check_docker || exit 1

    local compose_cmd=$(build_compose_command "$environment" "ps")

    eval "$compose_cmd"
}

# =============================================================================
# COMMAND: LOGS
# =============================================================================

cmd_logs() {
    local environment=$1
    local service=${2:-}
    local follow=${3:-false}

    log_header "Logs - $environment"

    load_env "$environment" || exit 1
    check_docker || exit 1

    local compose_cmd=$(build_compose_command "$environment" "logs")

    if [[ "$follow" == "-f" ]] || [[ "$follow" == "--follow" ]]; then
        compose_cmd="$compose_cmd -f"
    else
        compose_cmd="$compose_cmd --tail=100"
    fi

    if [[ -n "$service" ]]; then
        compose_cmd="$compose_cmd $service"
    fi

    eval "$compose_cmd"
}

# =============================================================================
# COMMAND: MIGRATE
# =============================================================================

cmd_migrate() {
    local environment=$1

    log_header "Applicazione Migrazioni - $environment"

    # Carica env e verifica stato
    load_env "$environment" || exit 1
    init_state_file "$environment"

    # Applica migrazioni Supabase
    if is_profile_enabled "supabase"; then
        log_info "Applicazione migrazioni Supabase..."
        bash scripts/migrate-supabase.sh "$environment"
    fi

    # Applica migrazioni n8n
    if is_profile_enabled "n8n"; then
        log_info "Applicazione migrazioni n8n..."
        bash scripts/migrate-n8n.sh "$environment"
    fi

    log_success "Migrazioni completate"
}

# =============================================================================
# COMMAND: BACKUP
# =============================================================================

cmd_backup() {
    local environment=$1

    log_header "Backup Manuale - $environment"

    load_env "$environment" || exit 1
    check_docker || exit 1

    if ! is_profile_enabled "backup"; then
        log_error "Backup non abilitato per questo ambiente"
        log_info "Abilita backup in: environments/${environment}/.env"
        exit 1
    fi

    # Verifica che container backup sia running
    local backup_container="${PROJECT_NAME}-backup"
    if ! docker ps --format '{{.Names}}' | grep -q "^${backup_container}$"; then
        log_error "Container backup non in esecuzione"
        log_info "Avvia prima i servizi: ./platform.sh up $environment"
        exit 1
    fi

    log_info "Esecuzione backup..."

    # Esegui backup script nel container
    docker exec "$backup_container" /app/backup.sh

    if [[ $? -eq 0 ]]; then
        log_success "Backup completato"
        log_info "Location: ./backups/"
    else
        log_error "Errore durante backup"
        exit 1
    fi
}

# =============================================================================
# COMMAND: RESTORE
# =============================================================================

cmd_restore() {
    local environment=$1
    local backup_file=${2:-}

    log_header "Ripristino Backup - $environment"

    if [[ -z "$backup_file" ]]; then
        log_error "Specifica il file di backup da ripristinare"
        echo ""
        echo "Usage: ./platform.sh restore $environment <backup_file>"
        echo ""
        echo "Backup disponibili:"
        ls -lh backups/ 2>/dev/null || echo "  Nessun backup trovato"
        exit 1
    fi

    if [[ ! -f "$backup_file" ]]; then
        log_error "File di backup non trovato: $backup_file"
        exit 1
    fi

    load_env "$environment" || exit 1
    check_docker || exit 1

    log_warning "ATTENZIONE: Il ripristino sovrascriverà i dati esistenti!"
    if ! confirm "Continuare con il ripristino?"; then
        log_info "Ripristino annullato"
        exit 0
    fi

    local backup_container="${PROJECT_NAME}-backup"

    # Copia backup nel container
    log_info "Copia backup nel container..."
    docker cp "$backup_file" "${backup_container}:/tmp/restore.sql.gz"

    # Esegui restore
    log_info "Ripristino in corso..."
    docker exec "$backup_container" /app/restore.sh "/tmp/restore.sql.gz"

    if [[ $? -eq 0 ]]; then
        log_success "Ripristino completato"
    else
        log_error "Errore durante ripristino"
        exit 1
    fi
}

# =============================================================================
# COMMAND: HEALTH
# =============================================================================

cmd_health() {
    local environment=$1

    log_header "Health Check - $environment"

    load_env "$environment" || exit 1
    check_docker || exit 1

    bash scripts/health-check.sh "$environment"
}

# =============================================================================
# COMMAND: CLEAN
# =============================================================================

cmd_clean() {
    local environment=$1

    log_header "Pulizia Dati - $environment"

    log_warning "ATTENZIONE: Questa operazione eliminerà:"
    echo "  - Tutti i container"
    echo "  - Tutti i volumi Docker"
    echo "  - Tutti i dati persistenti"
    echo ""

    if ! confirm "Sei ASSOLUTAMENTE sicuro?" "n"; then
        log_info "Operazione annullata"
        exit 0
    fi

    log_warning "Ultima conferma..."
    if ! confirm "Digitare 'yes' per confermare:"; then
        log_info "Operazione annullata"
        exit 0
    fi

    load_env "$environment" || exit 1
    check_docker || exit 1

    # Stop e rimuovi containers
    log_info "Arresto containers..."
    local compose_cmd=$(build_compose_command "$environment" "down" "-v")
    eval "$compose_cmd"

    # Rimuovi volumi
    log_info "Rimozione volumi..."
    docker volume ls --filter "name=${VOLUME_PREFIX}" -q | xargs -r docker volume rm

    log_success "Pulizia completata"
}

# =============================================================================
# COMMAND: STATE
# =============================================================================

cmd_state() {
    local environment=$1

    show_state "$environment"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Verifica argomenti
    if [[ $# -lt 1 ]]; then
        show_help
        exit 1
    fi

    local command=$1

    # Help
    if [[ "$command" == "help" ]] || [[ "$command" == "-h" ]] || [[ "$command" == "--help" ]]; then
        show_help
        exit 0
    fi

    # Verifica ambiente
    if [[ $# -lt 2 ]]; then
        log_error "Specifica l'ambiente: dev, staging, prod"
        echo ""
        show_help
        exit 1
    fi

    local environment=$2
    shift 2

    # Valida ambiente
    if [[ ! "$environment" =~ ^(dev|staging|prod)$ ]]; then
        log_error "Ambiente non valido: $environment"
        log_info "Ambienti supportati: dev, staging, prod"
        exit 1
    fi

    # Verifica che ambiente sia configurato
    if [[ ! -f "environments/${environment}/.env" ]]; then
        log_error "Ambiente non configurato: $environment"
        log_info "Esegui prima: ./install.sh $environment"
        exit 1
    fi

    # Esegui comando
    case $command in
        up)
            cmd_up "$environment"
            ;;
        down)
            cmd_down "$environment"
            ;;
        restart)
            cmd_restart "$environment"
            ;;
        status)
            cmd_status "$environment"
            ;;
        logs)
            cmd_logs "$environment" "$@"
            ;;
        migrate)
            cmd_migrate "$environment"
            ;;
        backup)
            cmd_backup "$environment"
            ;;
        restore)
            cmd_restore "$environment" "$@"
            ;;
        health)
            cmd_health "$environment"
            ;;
        clean)
            cmd_clean "$environment"
            ;;
        state)
            cmd_state "$environment"
            ;;
        *)
            log_error "Comando sconosciuto: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main
main "$@"
