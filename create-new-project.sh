#!/usr/bin/env bash

# =============================================================================
# Create New Project from Template
# =============================================================================
# Helper script per creare velocemente nuovo progetto dal template
#
# Usage: ./create-new-project.sh <project-name> [template-url]

set -euo pipefail

# Colori
readonly COLOR_RESET='\033[0m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'

log_info() { echo -e "${COLOR_BLUE}ℹ ${COLOR_RESET}$@"; }
log_success() { echo -e "${COLOR_GREEN}✓${COLOR_RESET} $@"; }
log_warning() { echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $@"; }

# =============================================================================
# USAGE
# =============================================================================

show_usage() {
    cat << EOF
${COLOR_CYAN}Create New Project from Local Platform Kit Template${COLOR_RESET}

Usage:
  $0 <project-name> [template-url]

Arguments:
  project-name    Nome del nuovo progetto (es: my-saas-app)
  template-url    URL template Git (opzionale)

Examples:
  # Clone da questo template
  $0 my-new-project

  # Clone da template custom
  $0 my-new-project https://github.com/me/local-platform-kit.git

  # Clone da GitHub template già configurato
  $0 my-new-project git@github.com:me/local-platform-kit.git

Notes:
  - Se template-url non specificato, usa directory corrente come template
  - Il progetto sarà creato in ./PROJECT-NAME/
  - Eseguirà automaticamente ./init-project.sh nel nuovo progetto
EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Parse arguments
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi

    local PROJECT_NAME=$1
    local TEMPLATE_URL=${2:-}

    # Sanitize project name
    PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

    echo ""
    log_info "Creating new project: ${COLOR_CYAN}${PROJECT_NAME}${COLOR_RESET}"
    echo ""

    # Check if directory exists
    if [[ -d "$PROJECT_NAME" ]]; then
        log_warning "Directory $PROJECT_NAME already exists!"
        echo -n "Remove and continue? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            exit 0
        fi
        rm -rf "$PROJECT_NAME"
    fi

    # Clone template
    if [[ -n "$TEMPLATE_URL" ]]; then
        log_info "Cloning from: $TEMPLATE_URL"
        git clone "$TEMPLATE_URL" "$PROJECT_NAME"
    else
        log_info "Copying current directory as template..."
        # Copy current dir, excluding some directories
        rsync -av \
            --exclude='.git' \
            --exclude='node_modules' \
            --exclude='environments/*/.*' \
            --exclude='backups' \
            --exclude='exports' \
            --exclude='.examples' \
            . "$PROJECT_NAME"/
    fi

    cd "$PROJECT_NAME"

    # Remove git history if exists
    if [[ -d .git ]]; then
        log_info "Removing template git history..."
        rm -rf .git
    fi

    # Run init-project.sh
    log_info "Initializing project..."
    echo ""

    if [[ -f init-project.sh ]]; then
        # Make executable
        chmod +x init-project.sh

        # Run interactively
        ./init-project.sh
    else
        log_warning "init-project.sh not found, skipping initialization"
    fi

    # Summary
    echo ""
    log_success "Project created: ${COLOR_CYAN}${PROJECT_NAME}/${COLOR_RESET}"
    echo ""
    echo "Next steps:"
    echo "  ${COLOR_BLUE}cd $PROJECT_NAME${COLOR_RESET}"
    echo "  ${COLOR_BLUE}git remote add origin <your-repo-url>${COLOR_RESET}"
    echo "  ${COLOR_BLUE}git push -u origin main${COLOR_RESET}"
    echo ""
    echo "Then:"
    echo "  ${COLOR_BLUE}./install.sh dev${COLOR_RESET}"
    echo "  ${COLOR_BLUE}./platform.sh up dev${COLOR_RESET}"
    echo ""
}

main "$@"
