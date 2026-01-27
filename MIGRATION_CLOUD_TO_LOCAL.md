# Migrazione da Cloud a Self-Hosted

Guida completa per migrare da **Supabase Cloud** e **n8n Cloud** a installazioni self-hosted locali (staging e prod).

## 📋 Panoramica

```
Cloud Dev (Supabase + n8n)
         ↓
    [EXPORT]
         ↓
    Export Package
         ↓
    [DISTRIBUTE]
         ↓
    ┌─────────┴─────────┐
    ↓                   ↓
Staging Server     Prod Server
(self-hosted)     (self-hosted)
```

## 🎯 Strategia di Migrazione

### Cosa Esportiamo

**Supabase Cloud**:
- ✅ Schema completo (tabelle, funzioni, trigger, policies)
- ✅ Dati di tutte le tabelle
- ✅ Extensions (uuid, pgcrypto, etc.)
- ⚠️ Storage files (export separato necessario)

**n8n Cloud**:
- ✅ Workflows (definizioni complete)
- ✅ Workflow settings e tags
- ⚠️ Credenziali (devono essere ri-create manualmente)
- ⚠️ Executions history (opzionale)

---

## 📦 FASE 1: EXPORT DA CLOUD

### Prerequisiti

Sul tuo computer locale (dove hai accesso ai servizi cloud):

```bash
# Installa PostgreSQL client (per pg_dump)
# Ubuntu/Debian
sudo apt-get install postgresql-client

# macOS
brew install postgresql

# Verifica
pg_dump --version

# Installa jq (già installato se hai fatto install.sh)
sudo apt-get install jq  # Ubuntu
brew install jq          # macOS
```

### A. Prepara Credenziali Cloud

#### Supabase Cloud

1. **Trova le credenziali del database**:
   - Dashboard Supabase → Settings → Database
   - **Host**: `db.xxx.supabase.co`
   - **Port**: `5432`
   - **Database**: `postgres`
   - **User**: `postgres`
   - **Password**: La password del tuo progetto

2. **Connection String** (se disponibile):
   ```
   postgresql://postgres:[PASSWORD]@db.xxx.supabase.co:5432/postgres
   ```

#### n8n Cloud

1. **Crea API Key**:
   - n8n Cloud → Settings → API
   - Generate new API Key
   - Salva la chiave (la userai dopo)

2. **Ottieni URL**:
   - Esempio: `https://xxx.app.n8n.cloud`

### B. Esegui Export Automatico

Ho creato uno script automatico che fa tutto:

```bash
cd local-platform-kit

# Esegui script di export
./scripts/export-from-cloud.sh
```

Lo script ti chiederà:
1. **Supabase**: Project ID, Password, Host
2. **n8n**: URL, API Key
3. Cosa vuoi esportare

**Output**: Directory `exports/cloud-dev-TIMESTAMP/` con:
- `supabase_cloud_dev.sql.gz` (database completo)
- `n8n-workflows/*.json` (tutti i workflows)
- `import-to-staging.sh` (script pronto per import)
- `import-to-prod.sh` (script pronto per import)

### C. Export Manuale (Alternativa)

Se preferisci controllare tutto manualmente:

#### Supabase - Export Manuale

```bash
# Export con pg_dump
PGPASSWORD="your-password" pg_dump \
  -h db.xxx.supabase.co \
  -p 5432 \
  -U postgres \
  -d postgres \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --exclude-schema=_analytics \
  --exclude-schema=_realtime \
  > supabase_cloud_dev.sql

# Comprimi
gzip supabase_cloud_dev.sql
```

**Spiegazione flags**:
- `--clean`: Aggiunge DROP prima di CREATE
- `--if-exists`: Non fallisce se oggetti non esistono
- `--no-owner`: Non include comandi OWNER
- `--no-privileges`: Non include GRANT/REVOKE
- `--exclude-schema`: Esclude schema interni Supabase

#### n8n - Export Manuale Workflows

```bash
# Lista workflows
curl -H "X-N8N-API-KEY: your-api-key" \
  https://xxx.app.n8n.cloud/api/v1/workflows

# Export singolo workflow (ripeti per ogni ID)
curl -H "X-N8N-API-KEY: your-api-key" \
  https://xxx.app.n8n.cloud/api/v1/workflows/1 \
  | jq '.' > 001_workflow_name.json
```

---

## 🚀 FASE 2: SETUP STAGING

### A. Copia Export su Server Staging

```bash
# Da tuo computer locale a server staging
scp -r exports/cloud-dev-TIMESTAMP user@staging-server:~/

# Oppure usa rsync
rsync -avz exports/cloud-dev-TIMESTAMP user@staging-server:~/
```

### B. Setup su Server Staging

Accedi al server staging:

```bash
ssh user@staging-server
```

#### 1. Installa Local Platform Kit

```bash
# Clona repository
git clone <repo-url> local-platform-kit
cd local-platform-kit

# Rendi eseguibili
chmod +x install.sh platform.sh scripts/**/*.sh
```

#### 2. Configura Ambiente Staging

```bash
# Wizard di installazione
./install.sh staging

# Durante wizard:
# - Seleziona: n8n + Supabase
# - Abilita backup: Sì
# - Schedule: 0 3 * * * (3 AM)
# - Google Drive: Opzionale

# IMPORTANTE: Prendi nota delle credenziali generate!
```

#### 3. Review Configuration

```bash
# Modifica se necessario
nano environments/staging/.env

# IMPORTANTE: Cambia queste per staging:
# - N8N_BASIC_AUTH_USER=admin_staging
# - N8N_BASIC_AUTH_PASSWORD=<strong-password>
# - Tutte le password generate
```

#### 4. Avvia Servizi

```bash
./platform.sh up staging
```

Attendi che tutti i container siano running:

```bash
# Verifica
./platform.sh status staging
./platform.sh health staging
```

### C. Import Dati

#### Metodo 1: Script Automatico (Consigliato)

```bash
# Vai nella directory export
cd ~/cloud-dev-TIMESTAMP

# Esegui script di import
./import-to-staging.sh
```

Lo script:
1. Copia i backup nella posizione corretta
2. Ripristina database Supabase
3. Importa workflows n8n
4. Verifica salute servizi

#### Metodo 2: Import Manuale

```bash
cd local-platform-kit

# 1. Import Supabase
# Copia backup
cp ~/cloud-dev-TIMESTAMP/supabase_cloud_dev.sql.gz backups/supabase/

# Restore
./platform.sh restore staging backups/supabase/supabase_cloud_dev.sql.gz

# 2. Import n8n Workflows
# Copia workflows nelle migrazioni
cp ~/cloud-dev-TIMESTAMP/n8n-workflows/*.json migrations/n8n/workflows/

# Applica migrazioni (importa workflows)
./platform.sh migrate staging
```

### D. Configura n8n Credentials

**IMPORTANTE**: Le credenziali n8n NON vengono esportate per sicurezza.

```bash
# 1. Accedi a n8n staging
open http://staging-server:5679

# Login con credenziali da .env:
# User: admin_staging
# Pass: (vedi environments/staging/.env)

# 2. Per ogni workflow che usa credenziali:
# - Apri workflow
# - Vai al nodo che usa credenziali
# - Ricrea la credenziale
# - Salva workflow
```

**Tip**: Documenta tutte le credenziali necessarie prima della migrazione!

### E. Test Staging

```bash
# Health check
./platform.sh health staging

# Test Supabase
# Accedi a Studio: http://staging-server:3001
# Verifica:
# - Tabelle esistono
# - Dati presenti
# - RLS policies attive
# - Functions/Triggers funzionanti

# Test n8n
# Accedi a n8n: http://staging-server:5679
# Verifica:
# - Workflows importati
# - Test esecuzione workflow (manuale)
# - Verifica logs

# Test backup
./platform.sh backup staging
ls -lh backups/
```

---

## 🚀 FASE 3: SETUP PROD

**Ripeti gli stessi step per prod**, ma con alcune differenze:

### Differenze per Prod

1. **Porte diverse**:
   - n8n: 5680 (non 5679)
   - Supabase API: 8002 (non 8001)
   - Supabase Studio: 3002 (non 3001)

2. **Script di import**:
   ```bash
   # Su server prod
   cd ~/cloud-dev-TIMESTAMP
   ./import-to-prod.sh
   ```

3. **Credenziali più forti**:
   ```bash
   # environments/prod/.env
   N8N_BASIC_AUTH_PASSWORD=<very-strong-password>
   POSTGRES_PASSWORD=<very-strong-password>
   ```

4. **Backup più frequenti** (opzionale):
   ```bash
   # .env
   BACKUP_SCHEDULE="0 */6 * * *"  # Ogni 6 ore
   BACKUP_RETENTION_DAYS=90
   ```

5. **Monitoring setup** (vedi DEPLOYMENT.md)

---

## 🔄 FASE 4: CUTOVER (Switch da Cloud a Self-Hosted)

Quando sei pronto per fare lo switch definitivo:

### Pre-Cutover Checklist

- [ ] Staging testato completamente
- [ ] Prod configurato e testato
- [ ] Tutti i workflows funzionanti
- [ ] Credenziali configurate
- [ ] Backup funzionanti
- [ ] Team notificato
- [ ] Rollback plan pronto

### Cutover Steps

1. **Metti cloud dev in read-only** (se possibile)
   - Supabase: Revoca permessi write
   - n8n: Pause workflows attivi

2. **Export finale da cloud dev**:
   ```bash
   # Nuovo export con dati più recenti
   ./scripts/export-from-cloud.sh
   ```

3. **Import finale in prod**:
   ```bash
   # Su server prod
   ./platform.sh restore prod backups/supabase/latest.sql.gz
   ./platform.sh migrate prod
   ```

4. **Update DNS/Load Balancer**:
   - Punta a nuovo server prod
   - Esempio: api.tuodominio.com → prod-server:8002

5. **Update applicazioni client**:
   - Cambia SUPABASE_URL
   - Cambia n8n webhook URLs

6. **Monitor**:
   ```bash
   # Continuous monitoring
   watch -n 5 './platform.sh health prod'

   # Logs
   ./platform.sh logs prod -f
   ```

7. **Verifica tutto funziona**

8. **Disabilita cloud services** (dopo conferma)

### Rollback Plan

Se qualcosa va storto:

1. **Riattiva cloud services**
2. **Revert DNS**
3. **Revert client config**
4. **Debug issue offline**

---

## 📊 GESTIONE POST-MIGRAZIONE

### Migrazioni Future

Dopo la migrazione, usa il sistema di migrazioni normale:

```bash
# Nuova feature in staging
nano migrations/supabase/003_new_feature.sql
./platform.sh migrate staging

# Test in staging
# ...

# Quando OK, apply a prod
./platform.sh migrate prod
```

### Sync tra Ambienti

Per propagare modifiche da staging a prod:

```bash
# 1. Backup staging
./platform.sh backup staging

# 2. Copy to prod machine
scp backups/supabase/staging_latest.sql.gz prod-server:~/

# 3. Restore in prod (ATTENZIONE!)
# Su server prod:
./platform.sh restore prod ~/staging_latest.sql.gz
```

**ATTENZIONE**: Questo sovrascrive prod con staging!

### Workflow n8n Updates

```bash
# Staging: export workflow modificato
# n8n UI → Export workflow

# Prod: import manualmente o via API
curl -H "X-N8N-API-KEY: key" \
  -H "Content-Type: application/json" \
  -X POST \
  -d @workflow.json \
  http://localhost:5680/api/v1/workflows
```

---

## 🛠️ TROUBLESHOOTING

### Import Supabase Fallisce

**Problema**: Errori durante restore

**Soluzioni**:

```bash
# 1. Verifica file non corrotto
gunzip -t backups/supabase/file.sql.gz

# 2. Check logs
./platform.sh logs staging supabase-db

# 3. Import manualmente con verbose
gunzip -c backups/supabase/file.sql.gz | \
  docker exec -i platform-staging-supabase-db \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1

# 4. Se extension mancanti
docker exec -i platform-staging-supabase-db \
  psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS uuid-ossp;"
```

### n8n Workflows Non Si Importano

**Problema**: Import workflows fallisce

**Soluzioni**:

```bash
# 1. Verifica n8n running
./platform.sh health staging

# 2. Check n8n logs
./platform.sh logs staging n8n

# 3. Verifica JSON validi
for f in migrations/n8n/workflows/*.json; do
    echo "Checking $f"
    jq '.' "$f" > /dev/null || echo "INVALID: $f"
done

# 4. Import manuale via UI
# n8n → Workflows → Import from File
```

### Credenziali n8n Mancanti

**Problema**: Workflows errori "credentials not found"

**Soluzione**: Ri-crea tutte le credenziali:

1. Documenta credenziali necessarie da cloud dev
2. In staging/prod: Settings → Credentials
3. Crea ogni credenziale
4. Apri ogni workflow e assegna credenziale corretta

**Tip**: Esporta lista credenziali da cloud:

```bash
# Lista nomi credenziali (NON valori!)
curl -H "X-N8N-API-KEY: key" \
  https://xxx.app.n8n.cloud/api/v1/credentials \
  | jq -r '.data[] | .name + " (" + .type + ")"'
```

### Performance Issues Post-Migrazione

```bash
# Check risorse
docker stats

# Optimize Postgres
# Aggiungi in docker-compose.yml sotto supabase-db:
command:
  - "postgres"
  - "-c"
  - "shared_buffers=256MB"
  - "-c"
  - "max_connections=200"

# Restart
./platform.sh restart staging
```

---

## 📋 CHECKLIST COMPLETA

### Pre-Migrazione
- [ ] Backup completo cloud dev
- [ ] Documenta tutte le credenziali n8n
- [ ] Documenta custom configuration
- [ ] Test export su ambiente test
- [ ] Server staging/prod pronti
- [ ] Team informato

### Export
- [ ] Supabase database esportato
- [ ] n8n workflows esportati
- [ ] Credenziali documentate
- [ ] Storage files esportati (se necessari)
- [ ] Export verificato (integrity check)

### Import Staging
- [ ] Platform Kit installato
- [ ] Servizi avviati e healthy
- [ ] Database Supabase ripristinato
- [ ] Workflows n8n importati
- [ ] Credenziali n8n configurate
- [ ] Test funzionalità critiche
- [ ] Backup staging configurato

### Import Prod
- [ ] Tutti step staging ripetuti per prod
- [ ] Security hardening (vedi DEPLOYMENT.md)
- [ ] Monitoring configurato
- [ ] Backup automatici attivi
- [ ] DNS pronto per switch
- [ ] Rollback plan testato

### Post-Migrazione
- [ ] Cloud dev in read-only
- [ ] Cutover completato
- [ ] DNS aggiornato
- [ ] Client apps aggiornate
- [ ] Monitoring attivo
- [ ] Primi backup verificati
- [ ] Team training completato
- [ ] Documentazione aggiornata

---

## 💡 TIPS & BEST PRACTICES

1. **Test First**: Sempre testare import in staging prima di prod

2. **Incremental Migration**: Considera migrare un servizio alla volta

3. **Maintenance Window**: Pianifica cutover in finestra manutenzione

4. **Communication**: Comunica chiaramente timeline al team

5. **Rollback Ready**: Tieni cloud dev attivo per qualche giorno post-migrazione

6. **Monitor**: Monitora attivamente per primi giorni post-migrazione

7. **Document**: Documenta ogni issue e soluzione trovata

8. **Backup Before Cutover**: Ultimo backup cloud dev prima dello switch

---

## 📞 Support

Se hai problemi durante la migrazione:
1. Check logs: `./platform.sh logs <env>`
2. Check health: `./platform.sh health <env>`
3. Consulta TROUBLESHOOTING section sopra
4. Apri Issue su GitHub con dettagli

---

**Buona migrazione! 🚀**
