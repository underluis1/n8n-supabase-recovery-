# Local Platform Kit

Sistema completo e modulare per gestire **Supabase self-hosted**, **n8n** e **backup automatici** su infrastruttura locale.

## Caratteristiche

- **Modulare**: Installa solo i servizi che ti servono
- **Multi-Environment**: Dev, Staging, Production isolati
- **Migrazioni Versionati**: Sistema append-only per SQL e workflows
- **Backup Automatici**: Con supporto locale e Google Drive
- **Docker Compose v2**: Con profiles per controllo granulare
- **Gestione Centralizzata**: Un unico tool (`platform.sh`) per tutto
- **Production-Ready**: Scripts professionali, logging, health checks

## Architettura

```
┌─────────────────────────────────────────────────┐
│           LOCAL PLATFORM KIT                    │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │   n8n    │  │ Supabase │  │  Backup  │     │
│  └──────────┘  └──────────┘  └──────────┘     │
│       │              │              │          │
│       └──────────────┴──────────────┘          │
│                      │                         │
│             Docker Compose v2                  │
│              (with Profiles)                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Prerequisiti

- **Docker** >= 20.10 con Docker Compose v2
- **jq** per gestione JSON: `sudo apt-get install jq`
- **bash** >= 4.0
- **curl** per health checks
- **openssl** per generazione secrets

## Quick Start

### 1. Installazione

```bash
# Clona il repository
git clone <repo-url>
cd local-platform-kit

# Rendi eseguibili gli script
chmod +x install.sh platform.sh scripts/**/*.sh

# Esegui wizard di installazione
./install.sh dev
```

L'installer ti guiderà attraverso:
- Selezione servizi da installare
- Configurazione backup
- Generazione secrets sicuri
- Creazione file di configurazione

### 2. Avvio Servizi

```bash
# Avvia tutti i servizi configurati
./platform.sh up dev

# Verifica stato
./platform.sh status dev

# Visualizza logs
./platform.sh logs dev

# Health check completo
./platform.sh health dev
```

### 3. Accesso ai Servizi

**n8n:**
- URL: http://localhost:5678
- User: admin (configurabile)
- Pass: (vedi `environments/dev/.env`)

**Supabase:**
- API: http://localhost:8000
- Studio: http://localhost:3000
- Docs: https://supabase.com/docs

## Struttura del Progetto

```
local-platform-kit/
├── install.sh              # Setup wizard interattivo
├── platform.sh             # Tool principale gestione lifecycle
├── docker-compose.yml      # Compose con profiles
├── .env.example            # Template configurazione
│
├── environments/           # Configurazioni per ambiente
│   ├── dev/
│   │   ├── .env           # Variabili ambiente dev
│   │   └── state.json     # Stato migrazioni
│   ├── staging/
│   └── prod/
│
├── docker/                 # Configurazioni Docker
│   ├── n8n/
│   ├── supabase/
│   └── backup/
│       ├── Dockerfile
│       ├── backup.sh
│       ├── restore.sh
│       └── entrypoint.sh
│
├── migrations/             # Migrazioni versionati
│   ├── supabase/
│   │   ├── 001_init_schema.sql
│   │   └── 002_add_projects.sql
│   └── n8n/
│       └── workflows/
│           └── 001_example_workflow.json
│
├── scripts/                # Scripts di supporto
│   ├── lib/
│   │   ├── logger.sh
│   │   ├── env-loader.sh
│   │   └── state-manager.sh
│   ├── migrate-supabase.sh
│   ├── migrate-n8n.sh
│   └── health-check.sh
│
└── backups/                # Directory backup locali
    ├── n8n/
    └── supabase/
```

## Comandi Platform.sh

### Gestione Lifecycle

```bash
# Avvio servizi
./platform.sh up <env>

# Arresto servizi
./platform.sh down <env>

# Riavvio servizi
./platform.sh restart <env>

# Stato containers
./platform.sh status <env>
```

### Logs

```bash
# Tutti i logs (ultimi 100 righe)
./platform.sh logs dev

# Logs specifico servizio
./platform.sh logs dev n8n

# Follow logs in real-time
./platform.sh logs dev n8n -f
```

### Migrazioni

```bash
# Applica tutte le migrazioni pending
./platform.sh migrate dev

# Visualizza stato migrazioni
./platform.sh state dev
```

Il sistema:
- Traccia quali migrazioni sono state applicate
- Applica solo quelle nuove in ordine
- Supporta rollback (manuale via SQL)

### Backup e Restore

```bash
# Backup manuale
./platform.sh backup prod

# Ripristina da backup
./platform.sh restore prod backups/supabase/supabase_prod_20240101_020000.sql.gz

# I backup automatici vengono eseguiti secondo schedule configurato
```

### Health Check

```bash
# Verifica salute di tutti i servizi
./platform.sh health dev
```

Controlla:
- Container running
- Database connectivity
- API endpoints
- Service health endpoints

### Pulizia

```bash
# ATTENZIONE: Elimina tutti i dati!
./platform.sh clean dev
```

Rimuove:
- Containers
- Volumi Docker
- Dati persistenti

## Sistema di Migrazioni

### Supabase (SQL)

Le migrazioni Supabase sono file SQL versionati:

```sql
-- migrations/supabase/003_add_feature.sql

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.my_table (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_my_table_name ON app.my_table(name);
```

**Best Practices:**
- Naming: `NNN_descriptive_name.sql`
- Sempre idempotente (`IF NOT EXISTS`, `OR REPLACE`)
- Include commenti descrittivi
- Una feature per file

### n8n (Workflows JSON)

I workflows n8n sono file JSON versionati:

```bash
# Esporta workflow esistente
curl -u admin:password http://localhost:5678/api/v1/workflows/1 > \
  migrations/n8n/workflows/002_my_workflow.json
```

**Best Practices:**
- Naming: `NNN_workflow_name.json`
- Esporta da UI o API
- Rimuovi dati sensibili
- Versiona in git

### State Tracking

Lo stato è tracciato in `environments/{env}/state.json`:

```json
{
  "environment": "dev",
  "created_at": "2024-01-01T00:00:00Z",
  "last_updated": "2024-01-02T00:00:00Z",
  "migrations": {
    "supabase": {
      "applied": ["001_init_schema", "002_add_projects"],
      "last_migration": "002_add_projects",
      "last_applied_at": "2024-01-02T00:00:00Z"
    },
    "n8n": {
      "applied": ["001_example_workflow"],
      "last_migration": "001_example_workflow",
      "last_applied_at": "2024-01-02T00:00:00Z"
    }
  }
}
```

## Sistema di Backup

### Configurazione

In `environments/{env}/.env`:

```bash
BACKUP_ENABLED=true
BACKUP_SCHEDULE="0 2 * * *"  # 2 AM ogni giorno
BACKUP_RETENTION_DAYS=30

# Google Drive (opzionale)
BACKUP_GDRIVE_ENABLED=true
BACKUP_GDRIVE_REMOTE_NAME=gdrive
BACKUP_GDRIVE_FOLDER=/platform-backups
```

### Configurare rclone per Google Drive

```bash
# Entra nel container backup
docker exec -it platform-dev-backup bash

# Configura rclone
rclone config

# Testa connessione
rclone ls gdrive:/
```

### Backup Manuali

```bash
# Backup completo
./platform.sh backup prod

# I file vengono salvati in:
# - backups/n8n/n8n_prod_YYYYMMDD_HHMMSS.sql.gz
# - backups/supabase/supabase_prod_YYYYMMDD_HHMMSS.sql.gz
```

### Restore

```bash
# Lista backup disponibili
ls -lh backups/supabase/

# Ripristina specifico backup
./platform.sh restore prod backups/supabase/supabase_prod_20240101_020000.sql.gz
```

**ATTENZIONE:** Il restore sovrascrive i dati esistenti!

## Multi-Environment

### Porte per Ambiente

Ogni ambiente usa porte diverse:

| Servizio | Dev | Staging | Prod |
|----------|-----|---------|------|
| n8n | 5678 | 5679 | 5680 |
| Supabase API | 8000 | 8001 | 8002 |
| Supabase Studio | 3000 | 3001 | 3002 |
| Postgres | 5432 | 5433 | 5434 |

### Setup Nuovo Ambiente

```bash
# Staging
./install.sh staging
./platform.sh up staging

# Prod
./install.sh prod
./platform.sh up prod

# Applica migrazioni
./platform.sh migrate staging
./platform.sh migrate prod
```

## Docker Compose Profiles

I servizi sono organizzati in profiles:

```bash
# Solo n8n
docker compose --profile n8n up -d

# Solo Supabase
docker compose --profile supabase up -d

# n8n + Supabase
docker compose --profile n8n --profile supabase up -d

# Tutto (incluso backup)
docker compose --profile n8n --profile supabase --profile backup up -d
```

Il tool `platform.sh` gestisce automaticamente i profiles in base a `.env`.

## Troubleshooting

### Container non si avviano

```bash
# Verifica logs
./platform.sh logs dev

# Verifica Docker
docker ps -a
docker compose --profile n8n --profile supabase ps

# Restart
./platform.sh restart dev
```

### Problemi di rete

```bash
# Verifica network
docker network ls
docker network inspect platform-network-dev

# Ricrea network
./platform.sh down dev
./platform.sh up dev
```

### Postgres connection refused

```bash
# Verifica che Postgres sia ready
docker exec platform-dev-supabase-db pg_isready

# Controlla health
./platform.sh health dev
```

### Migrazioni fallite

```bash
# Visualizza stato
./platform.sh state dev

# Controlla logs migrazione
./platform.sh logs dev

# Reset stato (SOLO per dev/test!)
# Modifica manualmente environments/dev/state.json
```

### Backup fallito

```bash
# Verifica container backup
docker logs platform-dev-backup

# Esegui manualmente nel container
docker exec -it platform-dev-backup /app/backup.sh

# Verifica permessi directory
ls -la backups/
```

## Sicurezza

### Secrets

- **MAI** committare file `.env` in git
- Usa `.env.example` come template
- Genera secrets casuali: `openssl rand -base64 32`
- Rigenera JWT secrets per production

### Database Access

- Postgres è esposto solo su localhost di default
- Usa RLS (Row Level Security) in Supabase
- Cambia password di default
- Backup regolari

### n8n Credentials

- Usa credenziali separate per ambiente
- Non esportare credenziali nei workflows
- Attiva basic auth in production
- Considera OAuth per accessi esterni

## Performance

### Ottimizzazioni Docker

```yaml
# In docker-compose.yml, aggiungi:
services:
  n8n-postgres:
    command:
      - "postgres"
      - "-c"
      - "shared_buffers=256MB"
      - "-c"
      - "max_connections=200"
```

### Pulizia Periodica

```bash
# Rimuovi immagini inutilizzate
docker image prune -a

# Rimuovi volumi orfani
docker volume prune

# Rimuovi vecchi backup
find backups/ -mtime +30 -delete
```

## Contribuire

1. Fork del repository
2. Crea feature branch: `git checkout -b feature/nome-feature`
3. Commit: `git commit -m 'Add feature'`
4. Push: `git push origin feature/nome-feature`
5. Apri Pull Request

## License

MIT License - vedi LICENSE file

## Supporto

- Issues: [GitHub Issues](link)
- Docs: [Wiki](link)
- Community: [Discord/Slack](link)

## Credits

Costruito con:
- [Supabase](https://supabase.com)
- [n8n](https://n8n.io)
- [Docker](https://docker.com)
- [PostgreSQL](https://postgresql.org)

---

**Made with ❤️ for DevOps Engineers**
