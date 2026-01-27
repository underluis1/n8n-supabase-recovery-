# Bug Fixes - 2026-01-27

## 🐛 Bug #1: Porta sbagliata per Supabase Transaction Pooler

**Problema**:
`sync-from-dev-cloud.sh` usava porta **5432** (Session pooler) invece di **6543** (Transaction pooler) per `pg_dump`, causando errore di connessione.

**Errore**:
```
invalid command \restrict
Errore durante pg_dump
```

**Causa**:
- Session Pooler (5432) condivide connessioni → non supporta `pg_dump`
- Transaction Pooler (6543) dedica connessioni → supporta `pg_dump`

**Fix**: `scripts/sync-from-dev-cloud.sh`
- ✅ Cambiata porta da 5432 → 6543
- ✅ Aggiunto messaggio guida per trovare Transaction Pooler
- ✅ Aggiunto error handling dettagliato
- ✅ Creata documentazione completa: `docs/SUPABASE_POOLER_SETUP.md`

---

## 🐛 Bug #2: grep -P non supportato su macOS

**Problema**:
Lo script usava `grep -oP '^\d+'` che funziona solo su Linux (GNU grep) ma fallisce su macOS (BSD grep).

**Errore**:
```
grep: invalid option -- P
usage: grep [-abcdDEFGHhIiJLlMmnOopqRSsUVvwXxZz] ...
```

**Causa**:
- macOS usa BSD grep (non supporta `-P` per Perl regex)
- Linux usa GNU grep (supporta `-P`)

**Fix**: `scripts/sync-from-dev-cloud.sh`
- ✅ Sostituito `grep -oP '^\d+'` con `sed -E 's/.*\/([0-9]+)_.*/\1/'`
- ✅ Compatibile con BSD e GNU
- ✅ Testato su macOS

**Righe modificate**:
- Riga 88: Estrazione numero migrazione Supabase
- Riga 291: Estrazione numero workflow n8n (nuovo)
- Riga 329: Estrazione numero workflow n8n (singolo)
- Riga 370: Estrazione numero workflow n8n (sync nuovi)

---

## 🔐 Bug #3: Password/API Key non richieste dopo primo setup

**Problema**:
Password Supabase e n8n API Key non vengono salvate (per sicurezza) ma lo script non le richiedeva nuovamente nelle esecuzioni successive.

**Errore**:
```
Errore durante pg_dump
(password vuota)
```

**Fix**: `scripts/sync-from-dev-cloud.sh`
- ✅ Aggiunto check per `SUPABASE_PASSWORD` in `generate_supabase_migration()`
- ✅ Aggiunto check per `N8N_API_KEY` in `sync_n8n_workflows()`
- ✅ Richiede credenziali se non impostate

---

## 📚 Documentazione Aggiunta

### `docs/SUPABASE_POOLER_SETUP.md`
Guida completa per configurare Supabase Transaction Pooler:
- Differenza tra Session e Transaction pooler
- Guida passo-passo Supabase Dashboard
- Esempi host corretti/sbagliati
- Troubleshooting errori comuni
- Checklist rapida

### `.gitignore`
- ✅ Aggiunto `.dev-cloud-config` per non committare host configurati

---

## 🧪 Come Testare

### Test Bug #1 (Transaction Pooler)

```bash
# 1. Rimuovi vecchia config
rm .dev-cloud-config

# 2. Lancia script
./scripts/sync-from-dev-cloud.sh

# 3. Inserisci credenziali CORRETTE:
# Host: aws-0-REGION.pooler.supabase.com (nota il .pooler.)
# Password: la tua password

# 4. Crea migrazione → dovrebbe funzionare!
```

### Test Bug #2 (grep compatibilità)

```bash
# Testa numerazione automatica migrazioni
ls migrations/supabase/*.sql
# Dovrebbe trovare il prossimo numero senza errori grep
```

### Test Bug #3 (Password prompt)

```bash
# Lancia lo script senza password in memoria
./scripts/sync-from-dev-cloud.sh

# Dovrebbe chiedere password quando scegli opzione 1
```

---

## ✅ Checklist Pre-Uso

Prima di usare `sync-from-dev-cloud.sh`:

- [ ] `pg_dump` installato (`brew install postgresql`)
- [ ] Supabase Dashboard → Settings → Database → **Transaction** connection string
- [ ] Host contiene `.pooler.supabase.com`
- [ ] Password Supabase pronta
- [ ] n8n API Key pronta (per sync workflows)

---

## 🚀 Stato

Tutti i bug risolti e testati. Script pronto per essere usato dai clienti.

**File modificati**:
- `scripts/sync-from-dev-cloud.sh` (fix principali)
- `.gitignore` (security)
- `docs/SUPABASE_POOLER_SETUP.md` (documentazione)

**Compatibilità**:
- ✅ macOS (BSD grep, BSD sed)
- ✅ Linux (GNU grep, GNU sed)
- ✅ Supabase Cloud (Transaction Pooler)
- ✅ n8n Cloud API
