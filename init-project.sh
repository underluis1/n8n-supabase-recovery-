#!/usr/bin/env bash

# =============================================================================
# Init New Project - Local Platform Kit
# =============================================================================
# Inizializza un nuovo progetto pulendo esempi e configurando base
#
# Usage: ./init-project.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colori
readonly COLOR_RESET='\033[0m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'

log_info() { echo -e "${COLOR_BLUE}ℹ ${COLOR_RESET}$@"; }
log_success() { echo -e "${COLOR_GREEN}✓${COLOR_RESET} $@"; }
log_warning() { echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $@"; }
log_header() { echo -e "\n${COLOR_BOLD}${COLOR_CYAN}$@${COLOR_RESET}\n"; }

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

    echo -ne "${COLOR_YELLOW}?${COLOR_RESET} ${message} ${prompt}: "
    read -r response
    response=${response:-$default_value}

    [[ "$response" =~ ^[Yy]$ ]]
}

# =============================================================================
# BANNER
# =============================================================================

print_banner() {
    clear
    echo -e "${COLOR_CYAN}${COLOR_BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║     LOCAL PLATFORM KIT - NEW PROJECT SETUP           ║
║                                                       ║
║  Initialize a new project from this template         ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
    echo -e "${COLOR_RESET}"
}

# =============================================================================
# PROJECT INFO
# =============================================================================

get_project_info() {
    log_header "Project Information"

    echo -n "Project name (es: my-saas-app): "
    read -r PROJECT_NAME

    if [[ -z "$PROJECT_NAME" ]]; then
        log_warning "Project name cannot be empty"
        exit 1
    fi

    # Sanitize project name
    PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

    echo ""
    echo -n "Project description (optional): "
    read -r PROJECT_DESCRIPTION

    PROJECT_DESCRIPTION=${PROJECT_DESCRIPTION:-"Local Platform Kit project"}

    log_success "Project: $PROJECT_NAME"
    log_info "Description: $PROJECT_DESCRIPTION"
}

# =============================================================================
# CLEAN EXAMPLES
# =============================================================================

clean_example_migrations() {
    log_header "Cleaning Example Migrations"

    if confirm "Remove example migrations?"; then
        # Backup esempi
        if [[ -d migrations/supabase ]] && [[ "$(ls -A migrations/supabase/*.sql 2>/dev/null)" ]]; then
            mkdir -p .examples/migrations/supabase
            cp migrations/supabase/*.sql .examples/migrations/supabase/ 2>/dev/null || true
            rm migrations/supabase/*.sql
            log_success "Removed Supabase example migrations (backed up in .examples/)"
        fi

        if [[ -d migrations/n8n/workflows ]] && [[ "$(ls -A migrations/n8n/workflows/*.json 2>/dev/null)" ]]; then
            mkdir -p .examples/migrations/n8n/workflows
            cp migrations/n8n/workflows/*.json .examples/migrations/n8n/workflows/ 2>/dev/null || true
            rm migrations/n8n/workflows/*.json
            log_success "Removed n8n example workflows (backed up in .examples/)"
        fi

        # Crea README in migrations
        cat > migrations/supabase/README.md << 'EOF'
# Supabase Migrations

This directory will contain your project's SQL migrations.

## Create First Migration

```bash
# Method 1: Use sync script (recommended)
./scripts/sync-from-dev-cloud.sh

# Method 2: Manual
nano migrations/supabase/001_init_schema.sql
```

See parent README.md for migration best practices.
EOF

        cat > migrations/n8n/workflows/README.md << 'EOF'
# N8N Workflows

This directory will contain your project's n8n workflows.

## Export Workflows

```bash
# Method 1: Use sync script (recommended)
./scripts/sync-from-dev-cloud.sh

# Method 2: Via n8n API
curl -H "X-N8N-API-KEY: key" \
  https://your-n8n.app.n8n.cloud/api/v1/workflows/1 \
  > migrations/n8n/workflows/001_my_workflow.json
```

See parent README.md for workflow management.
EOF

        log_success "Example migrations cleaned"
    else
        log_info "Keeping example migrations"
    fi
}

# =============================================================================
# CLEAN ENVIRONMENTS
# =============================================================================

clean_environments() {
    log_header "Cleaning Environment Files"

    if confirm "Remove existing environment configurations?"; then
        rm -rf environments/*/
        mkdir -p environments/{dev,staging,prod}

        for env in dev staging prod; do
            touch environments/$env/.gitkeep
        done

        log_success "Environment directories cleaned"
        log_info "You'll configure these when running ./install.sh"
    fi
}

# =============================================================================
# UPDATE README
# =============================================================================

update_readme() {
    log_header "Updating README"

    if confirm "Update README with project info?"; then
        # Backup original
        cp README.md .examples/README.original.md 2>/dev/null || true

        # Create new README
        cat > README.md << EOF
# ${PROJECT_NAME}

${PROJECT_DESCRIPTION}

## Tech Stack

- **Supabase** (self-hosted): Backend as a Service
- **n8n** (self-hosted): Automation platform
- **Local Platform Kit**: Deployment & migration management

## Quick Start

\`\`\`bash
# Setup development environment
./install.sh dev
./platform.sh up dev

# Access services
# n8n: http://localhost:5678
# Supabase Studio: http://localhost:3000
# Supabase API: http://localhost:8000
\`\`\`

## Development Workflow

See [WORKFLOW.md](WORKFLOW.md) for complete development workflow.

### 1. Develop in Cloud

Work in your dev cloud environment (Supabase + n8n managed).

### 2. Extract Migrations

\`\`\`bash
# Export migrations from dev cloud
./scripts/sync-from-dev-cloud.sh
\`\`\`

### 3. Deploy to Staging/Prod

\`\`\`bash
# On staging/prod servers
git pull
./platform.sh migrate <env>
\`\`\`

## Project Structure

\`\`\`
${PROJECT_NAME}/
├── install.sh              # Setup wizard
├── platform.sh             # Platform management
├── docker-compose.yml      # Docker orchestration
├── migrations/             # Versioned migrations
│   ├── supabase/          # SQL migrations
│   └── n8n/               # n8n workflows
├── environments/           # Environment configs
│   ├── dev/
│   ├── staging/
│   └── prod/
└── scripts/                # Management scripts
    ├── sync-from-dev-cloud.sh
    ├── migrate-supabase.sh
    └── migrate-n8n.sh
\`\`\`

## Documentation

- [WORKFLOW.md](WORKFLOW.md) - Development workflow
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture
- [DEPLOYMENT.md](DEPLOYMENT.md) - Production deployment guide
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines

## Commands

\`\`\`bash
# Lifecycle
./platform.sh up <env>       # Start services
./platform.sh down <env>     # Stop services
./platform.sh restart <env>  # Restart services

# Migrations
./platform.sh migrate <env>  # Apply migrations
./platform.sh state <env>    # Show migration state

# Monitoring
./platform.sh status <env>   # Container status
./platform.sh health <env>   # Health checks
./platform.sh logs <env>     # View logs

# Backup
./platform.sh backup <env>   # Manual backup
./platform.sh restore <env> <file>
\`\`\`

## Environments

- **dev**: Development (cloud managed)
- **staging**: Pre-production (self-hosted) - Port 5679, 8001, 3001
- **prod**: Production (self-hosted) - Port 5680, 8002, 3002

## License

MIT

## Support

For issues related to:
- This project: [Project Issues](<your-repo-url>/issues)
- Local Platform Kit: [Template Issues](https://github.com/your-username/local-platform-kit/issues)
EOF

        log_success "README.md updated"
        log_info "Original backed up to .examples/README.original.md"
    fi
}

# =============================================================================
# GIT INITIALIZATION
# =============================================================================

init_git() {
    log_header "Git Initialization"

    if [[ -d .git ]]; then
        log_warning "Git repository already exists"

        if confirm "Reinitialize git (WARNING: removes history)?"; then
            rm -rf .git
            git init
            log_success "Git reinitialized"
        else
            log_info "Keeping existing git repository"
            return 0
        fi
    else
        if confirm "Initialize git repository?"; then
            git init
            log_success "Git initialized"
        else
            log_info "Skipping git initialization"
            return 0
        fi
    fi

    # Update .gitignore for examples
    if ! grep -q "^.examples/" .gitignore 2>/dev/null; then
        echo "" >> .gitignore
        echo "# Template examples (backup)" >> .gitignore
        echo ".examples/" >> .gitignore
    fi

    # Initial commit
    if confirm "Create initial commit?"; then
        git add .
        git commit -m "chore: initialize ${PROJECT_NAME} from Local Platform Kit template"
        log_success "Initial commit created"

        echo ""
        log_info "To push to remote:"
        echo "  git remote add origin <your-repo-url>"
        echo "  git branch -M main"
        echo "  git push -u origin main"
    fi
}

# =============================================================================
# CREATE PROJECT CONFIG
# =============================================================================

create_project_config() {
    log_header "Creating Project Config"

    cat > .project.json << EOF
{
  "name": "${PROJECT_NAME}",
  "description": "${PROJECT_DESCRIPTION}",
  "initialized_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "template": "local-platform-kit",
  "template_version": "1.0.0",
  "environments": {
    "dev": "cloud",
    "staging": "self-hosted",
    "prod": "self-hosted"
  }
}
EOF

    log_success "Created .project.json"
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================

show_summary() {
    log_header "Initialization Complete!"

    echo ""
    echo "Project: ${COLOR_BOLD}${PROJECT_NAME}${COLOR_RESET}"
    echo "Template: Local Platform Kit"
    echo ""

    log_success "Next Steps:"
    echo ""
    echo "1. Setup Development Environment:"
    echo "   ${COLOR_CYAN}./install.sh dev${COLOR_RESET}"
    echo ""
    echo "2. Start Services:"
    echo "   ${COLOR_CYAN}./platform.sh up dev${COLOR_RESET}"
    echo ""
    echo "3. Configure Dev Cloud Sync:"
    echo "   ${COLOR_CYAN}./scripts/sync-from-dev-cloud.sh${COLOR_RESET}"
    echo ""
    echo "4. Read Documentation:"
    echo "   ${COLOR_CYAN}cat WORKFLOW.md${COLOR_RESET}"
    echo ""

    if [[ -d .examples ]]; then
        log_info "Example migrations backed up in: ${COLOR_CYAN}.examples/${COLOR_RESET}"
    fi

    echo ""
    log_success "Happy coding! 🚀"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    print_banner

    log_warning "This will initialize a new project from this template"
    echo ""

    if ! confirm "Continue?"; then
        log_info "Initialization cancelled"
        exit 0
    fi

    # Steps
    get_project_info
    clean_example_migrations
    clean_environments
    update_readme
    create_project_config
    init_git

    # Summary
    show_summary
}

main "$@"
