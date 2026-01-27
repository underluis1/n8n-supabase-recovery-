#!/usr/bin/env bash

# =============================================================================
# Logger Library - Sistema di logging colorato
# =============================================================================

# Colori
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'

# Timestamp
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Log con livello
log() {
    local level=$1
    shift
    local message="$@"
    echo -e "[$(timestamp)] ${level} ${message}${COLOR_RESET}"
}

# Log info (blu)
log_info() {
    log "${COLOR_BLUE}[INFO]${COLOR_RESET}" "$@"
}

# Log success (verde)
log_success() {
    log "${COLOR_GREEN}[SUCCESS]${COLOR_RESET}" "$@"
}

# Log warning (giallo)
log_warning() {
    log "${COLOR_YELLOW}[WARNING]${COLOR_RESET}" "$@"
}

# Log error (rosso)
log_error() {
    log "${COLOR_RED}[ERROR]${COLOR_RESET}" "$@" >&2
}

# Log debug (magenta)
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log "${COLOR_MAGENTA}[DEBUG]${COLOR_RESET}" "$@"
    fi
}

# Header per sezioni
log_header() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_CYAN}================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}$@${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}================================${COLOR_RESET}"
    echo ""
}

# Spinner per operazioni lunghe
spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %10 ))
        printf "\r${COLOR_CYAN}${spin:$i:1}${COLOR_RESET} ${message}..."
        sleep 0.1
    done
    printf "\r${COLOR_GREEN}✓${COLOR_RESET} ${message}... Done\n"
}

# Prompt per conferma
confirm() {
    local message=$1
    local default=${2:-n}

    if [[ $default == "y" ]]; then
        local prompt="[Y/n]"
        local default_value="y"
    else
        local prompt="[y/N]"
        local default_value="n"
    fi

    echo -ne "${COLOR_YELLOW}? ${message} ${prompt}:${COLOR_RESET} "
    if ! read -r response; then
        response=$default_value
    fi
    response=${response:-$default_value}

    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %3d%%" $percentage

    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Export functions
export -f timestamp
export -f log
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_debug
export -f log_header
export -f spinner
export -f confirm
export -f progress_bar
