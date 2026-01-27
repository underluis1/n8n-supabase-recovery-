# Development Workflow - Dev Cloud to Staging/Prod

Workflow completo per sviluppo con **Dev Cloud** e deployment su **Staging/Prod Self-hosted**.

## 🏗️ Architettura del Tuo Setup

```
┌─────────────────────────────────────────────────────────────┐
│                     DEV (CLOUD)                             │
│  - Supabase Cloud (managed)                                 │
│  - n8n Cloud (managed)                                      │
│                                                              │
│  Qui sviluppi e testi                                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ Export migrazioni
                       │ (SQL + JSON workflows)
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              GIT REPOSITORY (questo)                        │
│                                                              │
│  migrations/                                                │
│  ├── supabase/                                             │
│  │   ├── 001_init.sql                                      │
│  │   ├── 002_feature.sql                                   │
│  │   └── 003_new_feature.sql  ← Nuove migrazioni          │
│  └── n8n/                                                  │
│      └── workflows/                                         │
│          ├── 001_workflow.json                             │
│          └── 002_new_workflow.json  ← Nuovi workflows      │
│                                                              │
└────────────┬──────────────────────┬─────────────────────────┘
             │                      │
             │ git pull             │ git pull
             │ migrate              │ migrate
             ↓                      ↓
┌──────────────────────┐  ┌──────────────────────┐
│  STAGING (SERVER 1)  │  │   PROD (SERVER 2)    │
│  - Supabase local    │  │  - Supabase local    │
│  - n8n local         │  │  - n8n local         │
│                      │  │                      │
│  Self-hosted         │  │  Self-hosted         │
└──────────────────────┘  └──────────────────────┘
```

## 🔄 WORKFLOW COMPLETO

### FASE 1: Sviluppo in Dev Cloud

Lavori nel tuo ambiente dev cloud (Supabase + n8n managed).

**Esempio**:
- Crei nuova tabella in Supabase
- Crei nuovo workflow n8n
- Testi tutto

### FASE 2: Export Migrazioni (Locale)

Sul tuo computer locale, hai clonato questo repository.

```bash
cd local-platform-kit

# Script interattivo per estrarre migrazioni
./scripts/sync-from-dev-cloud.sh
```

**Prima volta** ti chiederà:
- Supabase Host: `db.xxx.supabase.co`
- Supabase Password: `***`
- n8n URL: `https://xxx.app.n8n.cloud`
- n8n API Key: `***` (da n8n → Settings → API)

**Poi menu interattivo**:
```
================================
Cosa vuoi fare?
================================
  1) Crea nuova migrazione Supabase
  2) Sync workflows n8n
  3) Entrambi
  4) Git commit & push
  5) Esci
```

#### Opzione 1: Migrazione Supabase

Crea nuovo file SQL versionato:

```bash
Scelta: 1

Nome migrazione: add_payments_table

Come vuoi generare la migrazione?
  1) Schema dump completo
  2) Schema diff (richiede setup)
  3) Scrivo SQL manualmente [consigliato]

Scelta: 3
```

Crea file: `migrations/supabase/003_add_payments_table.sql`

Apre editor, scrivi SQL:

```sql
-- =============================================================================
-- Migration: 003_add_payments_table
-- Description: Aggiunge tabella pagamenti
-- =============================================================================

SET search_path TO app, public;

CREATE TABLE IF NOT EXISTS app.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES app.users(id),
    amount DECIMAL(10,2) NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_user_id ON app.payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON app.payments(status);
```

Salva ed esci. File creato nel repository!

#### Opzione 2: Sync Workflows n8n

```bash
Scelta: 2

Opzioni:
  1) Sync tutti i workflows (sovrascrive esistenti)
  2) Export singolo workflow
  3) Export solo nuovi workflows

Scelta: 3  # Consigliato per nuovi workflows
```

Lo script:
- Interroga n8n Cloud API
- Trova workflows NON ancora nel repository
- Li esporta come JSON numerati
- Li salva in `migrations/n8n/workflows/`

**Esempio output**:
```
New workflow: Payment Processor
Exported: migrations/n8n/workflows/003_payment_processor.json

New workflow: Email Notifications
Exported: migrations/n8n/workflows/004_email_notifications.json
```

### FASE 3: Git Commit & Push

```bash
# Opzione 4 nel menu
Scelta: 4

# Mostra modifiche
git status --short migrations/

# Commit
Messaggio commit: feat: add payment system

# Push (opzionale)
Push su remote? [y/N]: y
```

Ora il repository contiene le nuove migrazioni!

### FASE 4: Deploy su Staging

Sul **server staging**, hai già fatto setup iniziale:

```bash
# Setup iniziale (solo prima volta)
git clone <repo-url> local-platform-kit
cd local-platform-kit
./install.sh staging
./platform.sh up staging
```

**Ogni volta che vuoi deployare nuove migrazioni**:

```bash
cd local-platform-kit

# Pull ultime modifiche
git pull origin main

# Applica migrazioni
./platform.sh migrate staging
```

**Output**:
```
========================================
Migrazioni Supabase - staging
========================================

Trovate 3 migrazioni
Skip (già applicata): 001_init
Skip (già applicata): 002_feature
Applicazione: 003_add_payments_table
✓ Migrazione applicata: 003_add_payments_table

========================================
Migrazioni N8N - staging
========================================

Trovati 4 workflows
Skip (già importato): 001_workflow
Skip (già importato): 002_workflow
Import: 003_payment_processor
✓ Workflow importato: 003_payment_processor
Import: 004_email_notifications
✓ Workflow importato: 004_email_notifications

========================================
Riepilogo
========================================
Supabase: Applicate 1, Skipped 2
n8n: Importati 2, Skipped 2
```

### FASE 5: Test su Staging

```bash
# Verifica servizi
./platform.sh health staging

# Accedi a Supabase Studio
http://staging-server:3001

# Verifica tabella payments creata
# Verifica dati, RLS, etc.

# Accedi a n8n
http://staging-server:5679

# Verifica workflows importati
# IMPORTANTE: Configura credenziali nei workflows!
# (le credenziali NON vengono esportate)

# Test workflow manualmente
```

### FASE 6: Deploy su Prod

Quando staging è OK:

```bash
# Sul server prod
cd local-platform-kit

git pull origin main
./platform.sh migrate prod

# Verifica
./platform.sh health prod

# Test
# ...

# Backup dopo deploy
./platform.sh backup prod
```

---

## 📋 WORKFLOW GIORNALIERO

### Scenario Tipico

**Lunedì mattina** - Nuova feature:

```bash
# 1. Sviluppi in dev cloud
# - Modifichi Supabase schema
# - Crei workflow n8n
# - Testi

# 2. Export migrazioni (sul tuo PC)
cd local-platform-kit
./scripts/sync-from-dev-cloud.sh
# → Crea migrazione SQL
# → Export workflows
# → Git commit & push

# 3. Deploy staging (SSH su staging)
cd local-platform-kit
git pull
./platform.sh migrate staging
# → Test

# 4. Deploy prod (quando OK)
# SSH su prod
git pull
./platform.sh migrate prod
./platform.sh backup prod
```

**Fine!** 🎉

---

## 🎯 CHEAT SHEET

### Sul Tuo Computer (Dev)

```bash
# Export migrazioni da cloud dev
./scripts/sync-from-dev-cloud.sh

# Workflow veloce:
# 1) Crea migrazione SQL
# 2) Sync workflows n8n
# 3) Commit & push
```

### Su Server Staging

```bash
# Deploy migrazioni
cd local-platform-kit
git pull
./platform.sh migrate staging

# Verifica
./platform.sh health staging
./platform.sh status staging

# Logs se problemi
./platform.sh logs staging
```

### Su Server Prod

```bash
# Deploy migrazioni
cd local-platform-kit
git pull
./platform.sh migrate prod

# Backup post-deploy
./platform.sh backup prod

# Verifica
./platform.sh health prod
```

---

## ⚙️ SETUP INIZIALE (Una Tantum)

### 1. Sul Tuo Computer Locale

```bash
# Clone repository
git clone <repo-url>
cd local-platform-kit

# Configura remote Git (se nuovo repo)
git remote add origin <your-git-url>

# Prima sync da dev cloud
./scripts/sync-from-dev-cloud.sh
# Configura credenziali cloud
# Export tutte le migrazioni esistenti

# Commit iniziale
git add .
git commit -m "feat: initial migrations from dev cloud"
git push -u origin main
```

### 2. Su Server Staging

```bash
# Clone repository
git clone <repo-url> local-platform-kit
cd local-platform-kit

# Setup staging
./install.sh staging
# Wizard interattivo: seleziona servizi, backup, etc.

# Avvia servizi
./platform.sh up staging

# OPZIONALE: Se hai dati esistenti da importare
# (solo prima volta per migrazione iniziale)
# Vedi MIGRATION_CLOUD_TO_LOCAL.md

# Applica migrazioni
./platform.sh migrate staging

# Configura credenziali n8n
# Accedi a http://server:5679
# Ricrea tutte le credenziali nei workflows

# Test
./platform.sh health staging
```

### 3. Su Server Prod

Identico a staging:

```bash
git clone <repo-url> local-platform-kit
cd local-platform-kit
./install.sh prod
./platform.sh up prod
./platform.sh migrate prod
# Configura credenziali n8n
./platform.sh health prod
```

---

## 🔐 GESTIONE CREDENZIALI N8N

**IMPORTANTE**: Le credenziali n8n (API keys, OAuth tokens, passwords) NON vengono esportate per sicurezza.

### Prima Migrazione

Documenta tutte le credenziali da dev cloud:

```bash
# Lista credenziali (SOLO nomi, non valori)
curl -H "X-N8N-API-KEY: your-key" \
  https://xxx.app.n8n.cloud/api/v1/credentials \
  | jq -r '.data[] | "- \(.name) (\(.type))"'
```

Salva in file:

```bash
# credentials.txt (NON committare!)
- Stripe API (stripeApi)
- SendGrid (sendGrid)
- PostgreSQL (postgres)
- Google OAuth (googleOAuth2)
```

### Su Staging/Prod

Per ogni credenziale:

1. Accedi a n8n: `http://server:5679`
2. Settings → Credentials → Create New
3. Seleziona tipo (Stripe, SendGrid, ecc.)
4. Inserisci valori (API key, ecc.)
5. Salva con **stesso nome** usato in dev

Poi per ogni workflow:
1. Apri workflow
2. Verifica nodi con credenziali
3. Assegna credenziale corretta (dropdown)
4. Salva

---

## 🔄 WORKFLOW ALTERNATIVO: Supabase CLI

Se vuoi usare Supabase CLI per diff automatico:

```bash
# Installa Supabase CLI
brew install supabase/tap/supabase  # macOS
# oppure: npm install -g supabase

# Link al progetto cloud
supabase link --project-ref xxx

# Genera diff automatico
supabase db diff --linked > migrations/supabase/003_auto_diff.sql

# Review e commit
git add migrations/supabase/003_auto_diff.sql
git commit -m "feat: add payment tables"
git push
```

Poi su staging/prod come sempre:

```bash
git pull
./platform.sh migrate staging
```

---

## 📊 STATE TRACKING

Il sistema traccia automaticamente quali migrazioni sono state applicate:

```bash
# Visualizza stato
./platform.sh state staging

# Output:
========================================
Stato Migrazioni - staging
========================================

Supabase:
  - Migrazioni applicate: 3
  - Ultima: 003_add_payments_table

n8n:
  - Migrazioni applicate: 4
  - Ultima: 004_email_notifications

Ultimo aggiornamento: 2024-01-27T10:30:00Z
```

Il tracking è in: `environments/staging/state.json`

**Importante**: Non modificare manualmente `state.json`!

---

## 🐛 TROUBLESHOOTING

### Migrazione SQL Fallisce

```bash
# Vedi errore
./platform.sh logs staging supabase-db

# Test SQL manualmente
docker exec -it platform-staging-supabase-db psql -U postgres

# Esegui SQL passo-passo per trovare errore

# Fix nel file migrations/supabase/003_*.sql
# Commit fix
git add migrations/
git commit -m "fix: correzione migrazione 003"
git push

# Su staging
git pull
# Reset stato (solo per quella migrazione)
nano environments/staging/state.json
# Rimuovi "003_add_payments_table" da array "applied"

# Riprova
./platform.sh migrate staging
```

### Workflow n8n Non Si Importa

```bash
# Verifica JSON valido
jq '.' migrations/n8n/workflows/003_*.json

# Verifica n8n running
./platform.sh health staging

# Import manuale
curl -u admin:password \
  -H "Content-Type: application/json" \
  -X POST \
  -d @migrations/n8n/workflows/003_*.json \
  http://localhost:5679/api/v1/workflows
```

### Git Conflicts

```bash
# Su server staging, se git pull ha conflicts
git pull
# CONFLICT in migrations/

# Resolve:
git status
nano <conflicted-file>
# Fix conflicts

git add .
git commit -m "merge: resolve conflicts"

# Poi applica migrazioni
./platform.sh migrate staging
```

---

## ✅ BEST PRACTICES

### 1. **Naming Conventions**

```bash
# Migrazioni SQL
001_init_schema.sql
002_add_users.sql
003_add_payments.sql
004_add_notifications.sql

# Workflows n8n
001_core_workflow.json
002_payment_processor.json
003_email_notifier.json
```

### 2. **Commit Messages**

```bash
# Feature
git commit -m "feat: add payment system"

# Bug fix
git commit -m "fix: correct payment calculation"

# Migration only
git commit -m "chore: add migration 003"
```

### 3. **Testing Flow**

```
Dev Cloud → Test
    ↓
Export migrations
    ↓
Staging → Test again
    ↓
Prod → Deploy + Backup
```

### 4. **Rollback Strategy**

Se migrazione in prod causa problemi:

```bash
# 1. Revert Git
git revert <commit-hash>
git push

# 2. Su prod
git pull

# 3. Ripristina database da backup
./platform.sh restore prod backups/supabase/pre-migration.sql.gz

# 4. Verifica
./platform.sh health prod
```

### 5. **Backup Prima di Deploy Prod**

```bash
# SEMPRE prima di migrate prod
./platform.sh backup prod

# Poi migrate
./platform.sh migrate prod

# Se tutto OK, backup post-deploy
./platform.sh backup prod
```

---

## 📚 RIEPILOGO COMANDI PRINCIPALI

```bash
# ====================================
# SUL TUO COMPUTER (Dev)
# ====================================

# Export migrazioni da cloud
./scripts/sync-from-dev-cloud.sh

# Commit e push
git add migrations/
git commit -m "feat: add feature"
git push

# ====================================
# SU STAGING
# ====================================

# Deploy
cd local-platform-kit
git pull
./platform.sh migrate staging

# Verifica
./platform.sh health staging
./platform.sh logs staging

# ====================================
# SU PROD
# ====================================

# Backup pre-deploy
./platform.sh backup prod

# Deploy
git pull
./platform.sh migrate prod

# Backup post-deploy
./platform.sh backup prod

# Verifica
./platform.sh health prod
```

---

Ora hai il workflow completo per sviluppare in cloud e deployare su self-hosted! 🚀
