# Local Platform Kit - Architettura Tecnica

Documentazione approfondita dell'architettura del sistema.

## Panoramica

Local Platform Kit è un sistema modulare per orchestrare Supabase self-hosted, n8n e backup automatici usando Docker Compose con profiles.

## Principi Architetturali

### 1. Separation of Concerns

Ogni servizio è isolato tramite Docker Compose profiles:
- `n8n`: Automation platform + Postgres dedicato
- `supabase`: Backend as a Service + stack completo
- `backup`: Sistema di backup separato

### 2. Infrastructure as Code

Tutta la configurazione è versionata:
- Docker Compose per orchestrazione
- Script bash per automazione
- Migrazioni SQL/JSON versionati
- State tracking in JSON

### 3. Immutabilità

- Container stateless (dati in volumi)
- Migrazioni append-only (no modifica)
- Configurazione tramite environment variables
- Rebuild sicuro dei container

### 4. Multi-Environment

Ambienti completamente isolati:
- File `.env` separati
- Porte diverse
- Volumi Docker separati
- State tracking indipendente

## Stack Tecnologico

### Core Services

```
┌─────────────────────────────────────────────┐
│                    n8n                      │
├─────────────────────────────────────────────┤
│  App: n8n (automation)                      │
│  DB: PostgreSQL 15                          │
│  Port: 5678 (configurable)                  │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│                 Supabase                    │
├─────────────────────────────────────────────┤
│  DB: PostgreSQL 15 (supabase fork)          │
│  API: Kong (gateway) + PostgREST            │
│  Auth: GoTrue                               │
│  Realtime: Phoenix Channels                 │
│  Storage: Storage API                       │
│  Studio: Admin UI                           │
│  Ports: 8000 (API), 3000 (Studio), 5432    │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│                  Backup                     │
├─────────────────────────────────────────────┤
│  Base: PostgreSQL 15 Alpine                 │
│  Tools: pg_dump, rclone, cron               │
│  Schedule: Configurable (default 2 AM)      │
│  Targets: Local + Google Drive             │
└─────────────────────────────────────────────┘
```

### Orchestration Layer

```
┌─────────────────────────────────────────────┐
│           platform.sh (main CLI)            │
├─────────────────────────────────────────────┤
│  - Lifecycle management                     │
│  - Migration orchestration                  │
│  - Backup/restore                           │
│  - Health checks                            │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│        Library Scripts (lib/)               │
├─────────────────────────────────────────────┤
│  logger.sh: Logging utilities               │
│  env-loader.sh: Environment management      │
│  state-manager.sh: Migration state          │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│      Docker Compose v2 + Profiles           │
├─────────────────────────────────────────────┤
│  --profile n8n                              │
│  --profile supabase                         │
│  --profile backup                           │
└─────────────────────────────────────────────┘
```

## Data Flow

### 1. Startup Flow

```
User: ./platform.sh up dev
         ↓
1. Load env from environments/dev/.env
         ↓
2. Check Docker availability
         ↓
3. Determine active profiles (N8N_ENABLED, SUPABASE_ENABLED, etc.)
         ↓
4. Build docker compose command with profiles
         ↓
5. Execute: docker compose --profile n8n --profile supabase up -d
         ↓
6. Wait for health checks
         ↓
7. Display access URLs
```

### 2. Migration Flow

```
User: ./platform.sh migrate dev
         ↓
1. Load environment
         ↓
2. Init state file if missing
         ↓
3. For each enabled profile:
   ├─ Supabase: scripts/migrate-supabase.sh
   │   ├─ Find *.sql files in migrations/supabase/
   │   ├─ Sort numerically
   │   ├─ For each file:
   │   │   ├─ Check if applied (state.json)
   │   │   ├─ If not: execute SQL in Postgres container
   │   │   └─ Mark as applied in state.json
   │   └─ Report summary
   │
   └─ N8N: scripts/migrate-n8n.sh
       ├─ Wait for n8n ready
       ├─ Find *.json files in migrations/n8n/workflows/
       ├─ Sort numerically
       ├─ For each file:
       │   ├─ Check if applied (state.json)
       │   ├─ If not: POST to n8n API
       │   └─ Mark as applied in state.json
       └─ Report summary
```

### 3. Backup Flow

```
Cron: BACKUP_SCHEDULE (e.g., 0 2 * * *)
         ↓
Container: platform-dev-backup
         ↓
Script: /app/backup.sh
         ↓
1. Generate timestamp
         ↓
2. If N8N_ENABLED:
   ├─ pg_dump n8n database
   ├─ gzip
   └─ Save to /backups/n8n/n8n_env_timestamp.sql.gz
         ↓
3. If SUPABASE_ENABLED:
   ├─ pg_dump supabase database
   ├─ gzip
   └─ Save to /backups/supabase/supabase_env_timestamp.sql.gz
         ↓
4. If BACKUP_GDRIVE_ENABLED:
   └─ rclone copy to Google Drive
         ↓
5. Cleanup old backups (> BACKUP_RETENTION_DAYS)
         ↓
6. Report summary
```

## State Management

### State File Schema

```json
{
  "environment": "dev",
  "created_at": "ISO-8601",
  "last_updated": "ISO-8601",
  "migrations": {
    "supabase": {
      "applied": ["001_init", "002_projects"],
      "last_migration": "002_projects",
      "last_applied_at": "ISO-8601"
    },
    "n8n": {
      "applied": ["001_example"],
      "last_migration": "001_example",
      "last_applied_at": "ISO-8601"
    }
  }
}
```

### State Operations

Gestite da `scripts/lib/state-manager.sh`:

- `init_state_file()`: Crea se non esiste
- `read_state()`: Leggi intero file
- `get_applied_migrations()`: Array migrazioni applicate
- `is_migration_applied()`: Check singola migrazione
- `mark_migration_applied()`: Registra nuova migrazione
- `get_last_migration()`: Ultima migrazione applicata
- `reset_migration_state()`: Reset (debug/test)
- `show_state()`: Pretty print stato

Usa `jq` per manipolazione JSON atomica.

## Networking

### Docker Network

```
Network: platform-network-{env}
Type: bridge
Isolation: per environment

Containers in network:
- n8n
- n8n-postgres
- supabase-db
- supabase-kong
- supabase-auth
- supabase-rest
- supabase-realtime
- supabase-storage
- supabase-meta
- supabase-studio
- backup
```

### Port Mapping

```
Host                Container
5678            →   n8n:5678
8000            →   kong:8000
3000            →   studio:3000
5432            →   supabase-db:5432
```

Porte host cambiano per ambiente (dev: 5678, staging: 5679, prod: 5680).

## Volumes

### Volume Schema

```
{VOLUME_PREFIX}_n8n_postgres_data
{VOLUME_PREFIX}_supabase_db_data
{VOLUME_PREFIX}_supabase_storage_data
{VOLUME_PREFIX}_supabase_kong_data
```

Dove `VOLUME_PREFIX = platform-{environment}`.

### Volume Management

- Creati automaticamente da Docker Compose
- Persistiti tra restart container
- Eliminati solo con `platform.sh clean` o `docker compose down -v`
- Backup via pg_dump (no copia diretta volumi)

## Security Considerations

### 1. Secrets Management

**Problema**: Secrets in plain text in `.env`

**Mitigazioni attuali**:
- `.env` in `.gitignore`
- Generazione automatica secrets casuali
- File permissions (chmod 600 consigliato)

**Miglioramenti futuri**:
- Integrazione con Vault/SOPS
- Docker secrets
- External secret management

### 2. Network Security

**Configurazione attuale**:
- Servizi esposti solo su localhost
- Network bridge isolata
- No TLS (sviluppo locale)

**Per produzione**:
- Reverse proxy (Traefik/Nginx)
- TLS certificates (Let's Encrypt)
- Firewall rules
- VPN access

### 3. Database Security

**Supabase**:
- Row Level Security (RLS) abilitato
- JWT authentication
- Service role key per operazioni privilegiate

**N8N**:
- Basic auth abilitato
- Encryption key per credenziali
- Database isolato

### 4. Backup Security

**Considerazioni**:
- Backup contengono dati sensibili
- Non criptati di default

**Raccomandazioni**:
- Cripta backup: `gpg --encrypt backup.sql.gz`
- Limita accesso directory backups/
- Google Drive con 2FA

## Performance Tuning

### PostgreSQL

Default configuration è ottimizzata per sviluppo. Per produzione:

```yaml
# docker-compose.yml
supabase-db:
  command:
    - "postgres"
    - "-c"
    - "max_connections=200"
    - "-c"
    - "shared_buffers=256MB"
    - "-c"
    - "effective_cache_size=1GB"
    - "-c"
    - "work_mem=16MB"
```

### N8N

```bash
# .env
N8N_EXECUTIONS_DATA_PRUNE=true
N8N_EXECUTIONS_DATA_MAX_AGE=168  # 7 days
```

## Monitoring

### Health Checks

Implementati tramite `scripts/health-check.sh`:

- Container running
- Database connectivity (pg_isready)
- HTTP endpoints (curl)
- Service-specific health endpoints

### Logging

```bash
# Centralizzato tramite Docker
docker compose logs -f

# Per servizio
docker compose logs -f n8n

# Con platform.sh
./platform.sh logs dev n8n -f
```

### Metrics (Future)

Considerare integrazione:
- Prometheus per metrics
- Grafana per dashboards
- AlertManager per alerting

## Scalability

### Limitazioni Correnti

- Single-node deployment
- No high availability
- No load balancing
- Backup single-threaded

### Scaling Strategies

**Vertical Scaling**:
- Aumenta risorse Docker (CPU, RAM)
- Ottimizza configurazione Postgres
- SSD per storage

**Horizontal Scaling** (future):
- Multiple n8n workers
- Postgres replication (streaming)
- Kong clustering
- Distributed backup

## Disaster Recovery

### Backup Strategy

**RPO (Recovery Point Objective)**: 24 ore (backup giornaliero)
**RTO (Recovery Time Objective)**: 1-2 ore (ripristino manuale)

### Recovery Scenarios

**1. Data Corruption**:
```bash
./platform.sh restore prod backups/latest.sql.gz
```

**2. Complete System Failure**:
```bash
# New host
./install.sh prod
./platform.sh up prod
./platform.sh restore prod backup.sql.gz
./platform.sh migrate prod
```

**3. Partial Service Failure**:
```bash
# Restart singolo servizio
docker compose --profile n8n restart n8n
```

## Testing Strategy

### Unit Testing

Non applicabile (infrastructure code).

### Integration Testing

```bash
# 1. Setup environment isolato
./install.sh test

# 2. Run tests
./platform.sh up test
./platform.sh migrate test
./platform.sh health test

# 3. Cleanup
./platform.sh clean test
```

### End-to-End Testing

Manuale:
1. Deploy completo
2. Test workflow n8n
3. Test API Supabase
4. Test backup/restore

## Maintenance

### Routine Tasks

**Giornaliere** (automatiche):
- Backup automatici
- Log rotation (Docker)

**Settimanali**:
- Review backup success
- Check disk space
- Review logs per errori

**Mensili**:
- Update immagini Docker
- Review security advisories
- Test restore procedure

**Trimestrali**:
- Disaster recovery drill
- Performance review
- Capacity planning

## Future Improvements

### Short Term
- [ ] Backup encryption
- [ ] Migration rollback support
- [ ] Automated testing
- [ ] CI/CD integration

### Medium Term
- [ ] Web UI per management
- [ ] Monitoring dashboard
- [ ] Multi-region backup
- [ ] Blue/green deployments

### Long Term
- [ ] Kubernetes support
- [ ] Multi-tenancy
- [ ] Auto-scaling
- [ ] SaaS offering

## References

- [Docker Compose Profiles](https://docs.docker.com/compose/profiles/)
- [Supabase Self-Hosting](https://supabase.com/docs/guides/self-hosting)
- [n8n Installation](https://docs.n8n.io/hosting/)
- [PostgreSQL Best Practices](https://wiki.postgresql.org/wiki/Don't_Do_This)
- [Bash Best Practices](https://google.github.io/styleguide/shellguide.html)
