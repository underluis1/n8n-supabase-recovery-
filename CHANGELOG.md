# Changelog

Tutte le modifiche significative al progetto saranno documentate in questo file.

Il formato è basato su [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
e questo progetto aderisce al [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-26

### Added

**Core Features**:
- Sistema completo di installazione con wizard interattivo (`install.sh`)
- Tool principale di management (`platform.sh`) con 10 comandi
- Docker Compose con profiles per controllo modulare dei servizi
- Supporto multi-environment (dev, staging, prod)

**Migrazioni**:
- Sistema di migrazioni versionato per Supabase (SQL)
- Sistema di migrazioni versionato per n8n (JSON workflows)
- State tracking con `state.json` per tracciare migrazioni applicate
- Script `migrate-supabase.sh` per applicazione automatica SQL
- Script `migrate-n8n.sh` per import automatico workflows

**Backup**:
- Container dedicato per backup automatici
- Supporto backup Postgres per n8n e Supabase
- Schedulazione via cron configurabile
- Supporto backup locali
- Supporto backup remoti su Google Drive tramite rclone
- Retention policy configurabile
- Script di restore con auto-detection tipo backup

**Servizi**:
- n8n latest con Postgres 15
- Supabase self-hosted stack completo:
  - PostgreSQL 15 (supabase fork)
  - Kong API Gateway
  - GoTrue (Auth)
  - PostgREST (API)
  - Realtime
  - Storage
  - Studio UI
  - Meta API

**Scripts e Utilities**:
- `logger.sh`: Sistema di logging colorato
- `env-loader.sh`: Gestione environment variables
- `state-manager.sh`: Gestione stato migrazioni
- `health-check.sh`: Health check completo di tutti i servizi

**Documentazione**:
- README.md completo con quickstart e troubleshooting
- ARCHITECTURE.md con dettagli tecnici approfonditi
- README per directory migrazioni con best practices
- Esempi di migrazioni SQL e workflows JSON
- .env.example con tutte le variabili disponibili

**DevOps**:
- .gitignore configurato per sicurezza
- Scripts eseguibili con permissions corrette
- Gestione errori e rollback
- Logging strutturato

### Security

- Generazione automatica secrets sicuri (32 caratteri)
- JWT secrets per Supabase
- Encryption key per n8n
- Password Postgres casuali
- File .env in .gitignore
- Row Level Security examples in migrazioni

## [Unreleased]

### Planned

- [ ] Backup encryption con GPG
- [ ] Support per rollback migrazioni
- [ ] CI/CD templates (GitHub Actions, GitLab CI)
- [ ] Monitoring con Prometheus/Grafana
- [ ] Automated testing suite
- [ ] Web UI per management
- [ ] Support per Kubernetes
- [ ] Multi-region backup replication

---

## Version Guidelines

Questo progetto segue Semantic Versioning:

- **MAJOR**: Breaking changes all'API o workflow
- **MINOR**: Nuove features backward-compatible
- **PATCH**: Bug fixes backward-compatible

### Types of Changes

- `Added` per nuove features
- `Changed` per modifiche a features esistenti
- `Deprecated` per features che saranno rimosse
- `Removed` per features rimosse
- `Fixed` per bug fixes
- `Security` per vulnerabilities fixes
