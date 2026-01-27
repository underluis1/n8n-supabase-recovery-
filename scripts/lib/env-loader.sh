#!/usr/bin/env bash

# =============================================================================
# Environment Loader - Caricamento variabili d'ambiente
# =============================================================================

# Carica variabili per un ambiente specifico
load_env() {
    local environment=$1
    local env_file="environments/${environment}/.env"

    if [[ ! -f "$env_file" ]]; then
        log_error "File di configurazione non trovato: $env_file"
        log_error "Esegui prima: ./install.sh"
        return 1
    fi

    log_debug "Caricamento variabili da: $env_file"

    # Carica variabili d'ambiente
    set -a
    source "$env_file"
    set +a

    # Verifica variabili critiche
    if [[ -z "$PROJECT_NAME" ]]; then
        log_error "PROJECT_NAME non definito in $env_file"
        return 1
    fi

    if [[ -z "$ENVIRONMENT" ]]; then
        export ENVIRONMENT="$environment"
    fi

    log_debug "Ambiente caricato: $ENVIRONMENT"
    return 0
}

# Verifica se un profile è abilitato
is_profile_enabled() {
    local profile=$1

    case $profile in
        n8n)
            [[ "${N8N_ENABLED:-false}" == "true" ]]
            ;;
        supabase)
            [[ "${SUPABASE_ENABLED:-false}" == "true" ]]
            ;;
        backup)
            [[ "${BACKUP_ENABLED:-false}" == "true" ]]
            ;;
        *)
            log_error "Profile sconosciuto: $profile"
            return 1
            ;;
    esac
}

# Ottieni profiles attivi
get_active_profiles() {
    local profiles=()

    if is_profile_enabled "n8n"; then
        profiles+=("n8n")
    fi

    if is_profile_enabled "supabase"; then
        profiles+=("supabase")
    fi

    if is_profile_enabled "backup"; then
        profiles+=("backup")
    fi

    echo "${profiles[@]}"
}

# Costruisci comando docker compose con profiles
build_compose_command() {
    local environment=$1
    shift
    local compose_args=("$@")

    local profiles=($(get_active_profiles))

    if [[ ${#profiles[@]} -eq 0 ]]; then
        log_error "Nessun profile abilitato per l'ambiente $environment"
        return 1
    fi

    local cmd="docker compose"

    # Aggiungi profiles
    for profile in "${profiles[@]}"; do
        cmd="$cmd --profile $profile"
    done

    # Aggiungi file env
    cmd="$cmd --env-file environments/${environment}/.env"

    # Aggiungi argomenti aggiuntivi
    for arg in "${compose_args[@]}"; do
        cmd="$cmd $arg"
    done

    echo "$cmd"
}

# Verifica requisiti Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker non trovato. Installalo da: https://docs.docker.com/get-docker/"
        return 1
    fi

    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose v2 non trovato"
        log_error "Aggiorna Docker alla versione piu recente"
        return 1
    fi

    # Verifica che docker daemon sia running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon non in esecuzione"
        log_error "Avvia Docker e riprova"
        return 1
    fi

    log_debug "Docker OK: $(docker --version)"
    log_debug "Docker Compose OK: $(docker compose version)"

    return 0
}

# Export functions
export -f load_env
export -f is_profile_enabled
export -f get_active_profiles
export -f build_compose_command
export -f check_docker
