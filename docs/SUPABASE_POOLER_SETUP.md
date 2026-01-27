# Supabase Transaction Pooler Setup

## 🎯 Perché Transaction Pooler?

Quando usi `sync-from-dev-cloud.sh` per estrarre migrazioni da Supabase Cloud, **DEVI usare il Transaction Pooler** (porta 6543) invece della connessione diretta (porta 5432).

### Differenza tra i pooler:

| Pooler | Porta | Uso | Comandi Supportati |
|--------|-------|-----|-------------------|
| **Session Pooler** | 5432 | Query normali | SELECT, INSERT, UPDATE, DELETE |
| **Transaction Pooler** | 6543 | DDL, dump, restore | CREATE, ALTER, DROP, pg_dump, pg_restore |

**Perché?**
- `pg_dump` richiede una connessione dedicata per mantenere transazioni aperte
- Session pooler condivide connessioni tra client → fallisce con `pg_dump`
- Transaction pooler dedica una connessione → funziona con `pg_dump`

---

## 📍 Dove Trovare le Credenziali (Supabase Dashboard)

### 1. Vai al tuo progetto Supabase
- https://app.supabase.com/project/YOUR_PROJECT_ID

### 2. Naviga a: **Settings → Database**

### 3. Trova sezione: **Connection String**

Vedrai 3 opzioni:
- ❌ **URI** (Direct connection) - NON usare per sync
- ❌ **Session pooler** - NON usare per sync
- ✅ **Transaction** - QUESTO per sync!

### 4. Copia il connection string "Transaction"

Formato:
```
postgresql://postgres.PROJECT_REF:PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres
```

### 5. Estrai i componenti

Da questo connection string:
```
postgresql://postgres.abcdefgh:myP@ssw0rd@aws-0-eu-central-1.pooler.supabase.com:6543/postgres
```

Estrai:
- **Host**: `aws-0-eu-central-1.pooler.supabase.com`
- **Password**: `myP@ssw0rd`
- **Porta**: `6543` (automatica nello script)

---

## ⚙️ Configurazione Script

Quando esegui `./scripts/sync-from-dev-cloud.sh` per la prima volta:

```bash
$ ./scripts/sync-from-dev-cloud.sh

================================
Configurazione Supabase Cloud Dev
================================

IMPORTANTE: Usa il Transaction Pooler per operazioni di dump/sync
  - Connection string: Settings > Database > Transaction
  - Formato: aws-0-[region].pooler.supabase.com (porta 6543)

Supabase DB Host (es: aws-0-eu-central-1.pooler.supabase.com): aws-0-eu-central-1.pooler.supabase.com
Supabase DB Password: ************
```

### ✅ Esempi di Host Corretti

```
aws-0-eu-central-1.pooler.supabase.com
aws-0-us-east-1.pooler.supabase.com
aws-0-ap-southeast-1.pooler.supabase.com
```

### ❌ Esempi SBAGLIATI (non funzioneranno)

```
db.abcdefgh.supabase.co          ← Direct connection
aws-0-eu-central-1.supabase.co   ← Session pooler
```

---

## 🔧 Troubleshooting

### Errore: "Connection refused" o "timeout"

**Causa**: Stai usando host sbagliato (probabilmente Session pooler o Direct)

**Soluzione**:
```bash
# Rimuovi config esistente
rm .dev-cloud-config

# Rilancia script e usa Transaction pooler
./scripts/sync-from-dev-cloud.sh
```

### Errore: "password authentication failed"

**Causa**: Password sbagliata o caratteri speciali non escaped

**Soluzione**:
1. Vai a Supabase Dashboard → Settings → Database
2. Clicca "Reset Database Password"
3. Usa nuova password (evita caratteri speciali complessi)
4. Aggiorna config:
   ```bash
   rm .dev-cloud-config
   ./scripts/sync-from-dev-cloud.sh
   ```

### Errore: "pg_dump: too many clients"

**Causa**: Stai usando Session pooler invece di Transaction pooler

**Soluzione**: Verifica di usare porta 6543 e host corretto del Transaction pooler

---

## 📚 Riferimenti

- [Supabase Connection Pooling](https://supabase.com/docs/guides/database/connecting-to-postgres#connection-pooler)
- [Transaction vs Session Pooling](https://supabase.com/docs/guides/database/connecting-to-postgres#how-connection-pooling-works)

---

## 🎯 Checklist Rapida

Prima di eseguire `sync-from-dev-cloud.sh`:

- [ ] Sono in Supabase Dashboard → Settings → Database
- [ ] Sto copiando il connection string **"Transaction"** (non URI o Session)
- [ ] L'host contiene `.pooler.supabase.com`
- [ ] Ho la password corretta
- [ ] Ho `pg_dump` installato localmente (`brew install postgresql` su Mac)

Fatto? → `./scripts/sync-from-dev-cloud.sh` 🚀
