# Contributing to Local Platform Kit

Grazie per l'interesse nel contribuire a Local Platform Kit!

## Code of Conduct

Questo progetto aderisce a standard di condotta professionale. Ci aspettiamo che tutti i contributori:
- Siano rispettosi
- Forniscano feedback costruttivo
- Si concentrino su ciò che è meglio per la comunità

## Come Contribuire

### Reporting Bugs

Se trovi un bug:

1. Verifica che non sia già stato segnalato nelle Issues
2. Crea una nuova Issue con:
   - Titolo descrittivo
   - Descrizione dettagliata del problema
   - Steps per riprodurre
   - Comportamento atteso vs attuale
   - Environment (OS, Docker version, etc.)
   - Logs rilevanti

**Esempio di Issue**:

```markdown
### Bug: Backup fails with permission denied

**Environment:**
- OS: Ubuntu 22.04
- Docker: 24.0.7
- Environment: prod

**Steps to reproduce:**
1. ./platform.sh up prod
2. ./platform.sh backup prod

**Expected:** Backup completes successfully
**Actual:** Error: permission denied writing to /backups

**Logs:**
```
[2024-01-26 02:00:00] ERROR: Permission denied
```
```

### Suggesting Enhancements

Per suggerire miglioramenti:

1. Crea una Issue con label `enhancement`
2. Descrivi chiaramente:
   - Problema che risolve
   - Soluzione proposta
   - Alternative considerate
   - Impatto su utenti esistenti

### Pull Requests

#### Setup Development Environment

```bash
# Fork repository
# Clone your fork
git clone https://github.com/YOUR_USERNAME/local-platform-kit
cd local-platform-kit

# Add upstream
git remote add upstream https://github.com/ORIGINAL/local-platform-kit

# Create branch
git checkout -b feature/my-feature
```

#### Development Workflow

1. **Make Changes**
   - Scrivi codice pulito e documentato
   - Segui stile esistente
   - Aggiungi commenti dove necessario

2. **Test Locally**
   ```bash
   # Test in ambiente dev
   ./install.sh dev
   ./platform.sh up dev
   # ... test your changes ...
   ./platform.sh clean dev
   ```

3. **Update Documentation**
   - Aggiorna README.md se necessario
   - Aggiungi entry in CHANGELOG.md
   - Documenta nuove features

4. **Commit**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

5. **Push**
   ```bash
   git push origin feature/my-feature
   ```

6. **Create Pull Request**
   - Descrizione chiara delle modifiche
   - Link alla Issue correlata
   - Screenshots se UI changes
   - Checklist pre-merge completata

#### Commit Message Guidelines

Usa [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: Nuova feature
- `fix`: Bug fix
- `docs`: Solo documentazione
- `style`: Formatting, no code change
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance

**Examples:**

```
feat(backup): add support for AWS S3

Implements S3 backend for backups alongside existing
Google Drive support.

Closes #123
```

```
fix(migration): handle SQL syntax errors gracefully

Migration script now catches SQL errors and provides
helpful error messages instead of silent failures.

Fixes #456
```

#### Pull Request Checklist

Prima di creare PR:

- [ ] Codice testato localmente
- [ ] Tutti gli script eseguibili (`chmod +x`)
- [ ] Documentazione aggiornata
- [ ] CHANGELOG.md aggiornato
- [ ] No file sensibili (.env, credentials)
- [ ] Commit messages seguono convenzioni
- [ ] Branch aggiornato con upstream/main

### Code Style

#### Bash Scripts

```bash
#!/usr/bin/env bash

# =============================================================================
# Script Name - Brief description
# =============================================================================
# Longer description if needed

set -euo pipefail  # Always use

# Constants in UPPER_CASE
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Functions with descriptive names
do_something() {
    local param=$1  # Local variables

    # Commenti per logica complessa
    if [[ condition ]]; then
        log_info "Doing something"
    fi
}

# Main function
main() {
    # Entry point
}

main "$@"
```

**Guidelines:**
- Usa `shellcheck` per validare
- Sempre `set -euo pipefail`
- Quote variables: `"$var"`
- Use `[[` instead of `[`
- Function names: lowercase_with_underscores
- Constants: UPPER_CASE
- Commenti per logica non ovvia

#### Docker

```yaml
# Commenti per sezioni
services:
  service-name:
    image: image:tag  # Use specific tags, not :latest
    container_name: ${PROJECT_NAME}-service
    restart: unless-stopped
    environment:
      - VAR=${VAR}
    volumes:
      - volume-name:/path
    networks:
      - network-name
```

**Guidelines:**
- Use specific image tags
- Named volumes
- Health checks dove possibile
- Resource limits per prod

#### SQL Migrations

```sql
-- =============================================================================
-- Migration: NNN_name
-- Description: Brief description
-- =============================================================================

SET search_path TO app, public;

-- Sezioni ben definite
-- =============================================================================
-- TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS app.my_table (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- columns...
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_my_table_field ON app.my_table(field);

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON TABLE app.my_table IS 'Description';
```

## Development Guidelines

### Adding New Features

1. **Discuss First**: Apri Issue per discutere l'idea
2. **Keep It Simple**: Segui principio KISS
3. **Backward Compatible**: Non rompere esistente
4. **Document**: README, inline comments, examples
5. **Test**: Almeno manualmente in dev

### Modifying Existing Code

1. **Understand First**: Leggi codice esistente
2. **Maintain Style**: Segui stile corrente
3. **Test Thoroughly**: Verifica nessuna regressione
4. **Update Docs**: Sincronizza documentazione

### Adding Dependencies

1. **Justify**: Spiega perché necessaria
2. **Evaluate**: Considera alternative
3. **Document**: Aggiungi in README prerequisiti
4. **Version**: Specifica versione minima

## Testing

### Manual Testing

```bash
# 1. Test installazione pulita
./install.sh test
./platform.sh up test

# 2. Test funzionalità modificata
# ... test steps ...

# 3. Test migrazioni
./platform.sh migrate test

# 4. Test backup/restore
./platform.sh backup test
./platform.sh restore test <backup-file>

# 5. Test health check
./platform.sh health test

# 6. Test cleanup
./platform.sh clean test
```

### Testing Checklist

- [ ] Fresh install funziona
- [ ] Upgrade da versione precedente funziona
- [ ] Multi-environment non interferiscono
- [ ] Backup/restore funzionano
- [ ] Scripts handle errors gracefully
- [ ] Logs sono chiari e utili

## Documentation

### What to Document

- **README.md**: Quick start, comandi principali
- **ARCHITECTURE.md**: Dettagli tecnici, design decisions
- **Inline Comments**: Logica non ovvia
- **Examples**: Use cases comuni
- **Troubleshooting**: Problemi noti e soluzioni

### Documentation Style

- Chiaro e conciso
- Esempi pratici
- Screenshots se utili
- Links a risorse esterne
- Aggiornato con codice

## Release Process

(Per maintainers)

1. **Version Bump**
   ```bash
   # Update version in relevant files
   nano CHANGELOG.md  # Add release notes
   ```

2. **Tag Release**
   ```bash
   git tag -a v1.1.0 -m "Release v1.1.0"
   git push origin v1.1.0
   ```

3. **Create Release**
   - GitHub Releases
   - Include CHANGELOG section
   - Attach assets if any

4. **Announce**
   - Update README if needed
   - Notify users (Discord, mailing list, etc.)

## Getting Help

- **Questions**: Apri Discussion (not Issue)
- **Real-time**: Discord/Slack channel
- **Email**: maintainer@example.com

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md
- Mentioned in release notes
- Credited in commit history

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Grazie per contribuire a Local Platform Kit!
