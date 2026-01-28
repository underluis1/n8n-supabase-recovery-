# Troubleshooting Guide

Questa guida risolve i problemi comuni che potresti incontrare con il Local Platform Kit.

## Indice

- [Supabase Services in Crash Loop](#supabase-services-in-crash-loop)
- [Volume già esistenti](#volume-già-esistenti)
- [Errori di migrazione](#errori-di-migrazione)

---

## Supabase Services in Crash Loop

### Sintomi

```bash
$ docker ps
CONTAINER ID   IMAGE                              STATUS
f842bddf8cfd   supabase/storage-api:v0.43.11     Restarting (1) 1 second ago
edb80ad97ed7   supabase/realtime:v2.25.50        Restarting (1) 2 seconds ago
d25bc12b114e   supabase/gotrue:v2.151.0          Restarting (1) 4 seconds ago
```

### Causa

I servizi Supabase (storage, auth, realtime) riavviano continuamente con errori tipo:
- `schema "storage" does not exist`
- `no schema has been selected to create in`
- `relation "storage.objects" does not exist`

Questo accade quando:
1. Stai usando volumi Docker preesistenti da un progetto precedente
2. Gli script di inizializzazione in `/docker-entrypoint-initdb.d/` non sono stati eseguiti
3. PostgreSQL esegue gli init scripts solo quando inizializza un database **vuoto**

### Soluzione

Esegui lo script di fix per inizializzare manualmente gli schema:

```bash
./scripts/fix-supabase-schemas.sh staging
```

Oppure segui questi passi manuali:

1. Verifica che il database sia in esecuzione:
```bash
docker ps | grep supabase-db
```

2. Applica gli script di init manualmente:
```bash
# Ruoli
docker exec -i -e PGPASSWORD=<your-password> platform-staging-supabase-db \
  psql -U postgres -d postgres < docker/supabase/volumes/db/init/01-init-roles.sql

# Schema
docker exec -i -e PGPASSWORD=<your-password> platform-staging-supabase-db \
  psql -U postgres -d postgres < docker/supabase/volumes/db/init/00-init-schemas.sql

# Storage migrations
curl -s https://raw.githubusercontent.com/supabase/storage/master/migrations/tenant/0001-initialmigration.sql | \
  docker exec -i -e PGPASSWORD=<your-password> platform-staging-supabase-db \
  psql -U postgres -d postgres

curl -s https://raw.githubusercontent.com/supabase/storage/master/migrations/tenant/0002-storage-schema.sql | \
  docker exec -i -e PGPASSWORD=<your-password> platform-staging-supabase-db \
  psql -U postgres -d postgres
```

3. Riavvia i servizi:
```bash
docker restart platform-staging-supabase-storage \
  platform-staging-supabase-auth \
  platform-staging-supabase-realtime
```

4. Verifica che i servizi siano attivi:
```bash
./platform.sh status staging
```

---

## Volume già esistenti

### Sintomi

All'avvio vedi warning tipo:
```
WARN[0000] volume "platform-staging_n8n_postgres_data" already exists but was created for project "n8n-supabase-migration"
```

### Causa

Stai riutilizzando volumi creati da un'altra istanza del progetto (diverso nome directory o PROJECT_NAME).

### Soluzioni

**Opzione 1: Riutilizza i volumi esistenti (Consigliato)**

I volumi funzioneranno comunque. Se i servizi non partono, vedi [Supabase Services in Crash Loop](#supabase-services-in-crash-loop).

**Opzione 2: Usa volumi esterni**

Modifica `docker-compose.yml` per marcare i volumi come esterni:

```yaml
volumes:
  n8n-postgres-data:
    name: ${VOLUME_PREFIX:-platform}_n8n_postgres_data
    external: true  # <-- Aggiungi questa riga
```

**Opzione 3: Pulisci e ricrea tutto (ATTENZIONE: Perdi i dati)**

```bash
# Ferma e rimuovi tutto
./platform.sh down staging

# Rimuovi volumi
docker volume ls | grep platform-staging | awk '{print $2}' | xargs docker volume rm

# Riavvia
./platform.sh up staging
```

---

## Errori di migrazione

### N8N Migration Failed

Se n8n non si avvia con errori di migrazione:

```bash
# Check logs
docker logs platform-staging-n8n

# Connettiti al database e verifica
docker exec -it platform-staging-n8n-postgres psql -U n8n -d n8n
\dt
```

### Supabase Migration Failed

Se le migrazioni Supabase falliscono:

```bash
# Verifica schema esistenti
docker exec -it platform-staging-supabase-db psql -U postgres -d postgres -c "\dn"

# Verifica tabelle storage
docker exec -it platform-staging-supabase-db psql -U postgres -d postgres -c "\dt storage.*"

# Applica fix
./scripts/fix-supabase-schemas.sh staging
```

---

## Supabase Studio Unhealthy

### Sintomi

```bash
$ docker ps
platform-staging-supabase-studio   Up 5 minutes (unhealthy)
```

### Causa

L'health check interno di Studio cerca localhost:3000 ma il servizio è su 0.0.0.0:3000.

### Impatto

**Nessun impatto reale**. Studio funziona correttamente su http://localhost:3001. L'health check è solo un problema di configurazione interna del container.

### Verifica

```bash
# Studio risponde correttamente
curl -s -o /dev/null -w "%{http_code}" http://localhost:3001
# Output: 307 (redirect, normale)
```

---

## Network già esistente

### Sintomi

```
WARN[0000] a network with name platform-network-staging exists but was not created for project
```

### Soluzione

Aggiungi `external: true` al network in `docker-compose.yml`:

```yaml
networks:
  platform-network:
    name: ${NETWORK_NAME:-platform-network}
    driver: bridge
    external: true  # <-- Aggiungi questa riga
```

---

## Permission Denied su Scripts

### Sintomi

```bash
$ ./platform.sh up dev
-bash: ./platform.sh: Permission denied
```

### Soluzione

```bash
chmod +x platform.sh
chmod +x scripts/*.sh
```

---

## Port già in uso

### Sintomi

```
Error starting userland proxy: listen tcp4 0.0.0.0:5678: bind: address already in use
```

### Soluzione

1. Trova il processo che usa la porta:
```bash
lsof -i :5678
```

2. Ferma il processo o modifica la porta in `environments/<env>/.env`:
```bash
N8N_PORT=5679
```

---

## Database Connection Timeout

### Sintomi

I servizi non riescono a connettersi al database.

### Soluzione

1. Verifica che il database sia healthy:
```bash
docker ps | grep postgres
```

2. Aumenta il timeout dell'health check in `docker-compose.yml`:
```yaml
healthcheck:
  interval: 10s
  timeout: 10s  # <-- Aumenta se necessario
  retries: 10   # <-- Aumenta se necessario
```

3. Verifica le credenziali in `.env`

---

## Bisogno di aiuto?

Se il problema persiste:

1. Raccogli i log:
```bash
./platform.sh logs staging > debug.log
docker ps -a >> debug.log
```

2. Crea una issue su GitHub con:
   - Descrizione del problema
   - Output di `docker ps -a`
   - Log rilevanti
   - File `.env` (rimuovi password/segreti)
