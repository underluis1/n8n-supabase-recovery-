# Quick Start Guide

Guida rapida per iniziare con Local Platform Kit in 5 minuti.

## Prerequisiti

```bash
# Verifica Docker
docker --version  # >= 20.10
docker compose version  # v2.x

# Installa jq se mancante
sudo apt-get install jq  # Ubuntu/Debian
# brew install jq  # macOS
```

## Installazione (3 Steps)

### 1. Setup

```bash
# Clona repository
git clone <repo-url>
cd local-platform-kit

# Rendi eseguibili gli script
chmod +x install.sh platform.sh scripts/**/*.sh
```

### 2. Installa

```bash
# Avvia wizard di installazione
./install.sh dev

# Segui le istruzioni:
# - Seleziona servizi (n8n + Supabase)
# - Abilita backup (opzionale)
# - Conferma avvio
```

### 3. Usa

```bash
# URL di accesso mostrati al termine installazione:

# n8n: http://localhost:5678
# User: admin
# Pass: changeme123 (vedi .env)

# Supabase Studio: http://localhost:3000
# Supabase API: http://localhost:8000
```

## Comandi Essenziali

```bash
# Stato servizi
./platform.sh status dev

# Logs
./platform.sh logs dev

# Health check
./platform.sh health dev

# Ferma tutto
./platform.sh down dev

# Riavvia
./platform.sh up dev
```

## Prossimi Passi

### 1. Aggiungi Prima Migrazione Supabase

```sql
# Crea: migrations/supabase/003_my_first_table.sql
SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.my_table (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

```bash
# Applica
./platform.sh migrate dev
```

### 2. Crea Primo Workflow n8n

1. Apri n8n: http://localhost:5678
2. Crea workflow
3. Esporta: Menu → Export
4. Salva come: `migrations/n8n/workflows/002_my_workflow.json`

```bash
# Importa in altro ambiente
./platform.sh migrate staging
```

### 3. Test Backup

```bash
# Backup manuale
./platform.sh backup dev

# Verifica file
ls -lh backups/

# Test restore (usa ambiente test!)
./install.sh test
./platform.sh up test
./platform.sh restore test backups/supabase/latest.sql.gz
```

## Troubleshooting Rapido

### Container non si avviano

```bash
# Verifica Docker daemon
docker info

# Logs dettagliati
./platform.sh logs dev

# Restart pulito
./platform.sh down dev
./platform.sh up dev
```

### Porta già in uso

```bash
# Trova processo che usa porta
sudo lsof -i :5678

# Cambia porta in .env
nano environments/dev/.env
# N8N_PORT=5679

# Restart
./platform.sh restart dev
```

### Migrazione fallita

```bash
# Visualizza stato
./platform.sh state dev

# Verifica SQL/JSON
cat migrations/supabase/003_*.sql

# Riprova
./platform.sh migrate dev
```

## Cheat Sheet

```bash
# LIFECYCLE
./platform.sh up <env>       # Avvia
./platform.sh down <env>     # Ferma
./platform.sh restart <env>  # Riavvia
./platform.sh status <env>   # Stato

# LOGS & MONITORING
./platform.sh logs <env> [service] [-f]
./platform.sh health <env>

# MIGRAZIONI
./platform.sh migrate <env>
./platform.sh state <env>

# BACKUP & RESTORE
./platform.sh backup <env>
./platform.sh restore <env> <file>

# CLEANUP (ATTENZIONE!)
./platform.sh clean <env>

# HELP
./platform.sh help
```

## Multi-Environment

```bash
# Setup staging
./install.sh staging
./platform.sh up staging
./platform.sh migrate staging

# Setup prod
./install.sh prod
./platform.sh up prod
./platform.sh migrate prod

# Tutti e 3 in parallelo (porte diverse)
./platform.sh status dev      # 5678, 8000, 3000
./platform.sh status staging  # 5679, 8001, 3001
./platform.sh status prod     # 5680, 8002, 3002
```

## Documentazione Completa

- **README.md**: Guida completa con tutte le features
- **ARCHITECTURE.md**: Dettagli tecnici e architettura
- **DEPLOYMENT.md**: Checklist per produzione
- **migrations/*/README.md**: Best practices migrazioni

## Supporto

- Issues: GitHub Issues
- Docs: [Wiki](link)
- Community: [Discord](link)

---

**Pronto in 5 minuti. Production-ready quando lo sei tu.**
