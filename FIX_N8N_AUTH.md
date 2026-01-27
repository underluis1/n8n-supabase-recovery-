# Fix n8n Authentication per Migrazioni

## Problema

Lo script `migrate-n8n.sh` fallisce con HTTP 401 perché n8n richiede autenticazione per l'API.

## Soluzioni

### Soluzione 1: API Key (Consigliata - Prod Ready)

```bash
# 1. Accedi a n8n
open http://localhost:5679  # staging
open http://localhost:5680  # prod

# 2. Completa setup owner se richiesto
# - Email
# - Password

# 3. Genera API Key
# Settings → API → Generate API Key

# 4. Aggiungi in .env
echo "N8N_API_KEY=n8n_api_your_key_here" >> environments/staging/.env

# 5. Riprova
./platform.sh migrate staging
```

### Soluzione 2: Disabilita Auth (Solo Dev/Test Locale)

**ATTENZIONE**: NON usare in produzione!

```bash
# 1. Modifica .env
nano environments/dev/.env

# 2. Cambia
N8N_BASIC_AUTH_ACTIVE=false

# 3. Rimuovi anche user/password per evitare owner setup
# Commenta queste righe:
# N8N_BASIC_AUTH_USER=admin
# N8N_BASIC_AUTH_PASSWORD=changeme123

# 4. Restart n8n
./platform.sh restart dev

# 5. Ora API funziona senza auth
curl http://localhost:5678/api/v1/workflows
```

## Come Funziona lo Script Aggiornato

Lo script `migrate-n8n.sh` ora supporta entrambi:

1. **API Key** (preferita):
   ```bash
   N8N_API_KEY=n8n_api_xxxxx
   ```

2. **Basic Auth** (fallback):
   ```bash
   N8N_BASIC_AUTH_USER=admin
   N8N_BASIC_AUTH_PASSWORD=password
   ```

Se `N8N_API_KEY` è presente, usa quella. Altrimenti prova basic auth.

## Esempio .env Completo

```bash
# Development (senza auth)
N8N_ENABLED=true
N8N_PORT=5678
N8N_BASIC_AUTH_ACTIVE=false

# Staging/Prod (con API key)
N8N_ENABLED=true
N8N_PORT=5679
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=secure_password_here
N8N_API_KEY=n8n_api_1234567890abcdef...
```

## Troubleshooting

### Test Manuale API

```bash
# Con API key
curl -H "X-N8N-API-KEY: n8n_api_xxxxx" http://localhost:5679/api/v1/workflows

# Con basic auth (potrebbe non funzionare con n8n recente)
curl -u admin:password http://localhost:5679/api/v1/workflows

# Senza auth (se disabilitata)
curl http://localhost:5678/api/v1/workflows
```

### Se API Key Non Funziona

1. Verifica che la key sia corretta (copia/incolla completo)
2. Verifica che n8n sia updated (versione recente supporta API key)
3. Controlla logs: `docker logs platform-staging-n8n`

### Se Basic Auth Non Funziona

n8n versioni recenti (>= 1.0) richiedono API key per l'API, anche se basic auth è attivo per la UI.

**Soluzione**: Genera API key come descritto sopra.

## Best Practices

### Development
- Disabilita auth per facilità sviluppo
- Genera workflows e testali
- Prima di committare: riabilita auth

### Staging/Prod
- **Sempre** usa auth
- Genera API key
- Rotazione API key periodica
- Non committare API key in git

## Workflow Consigliato

```bash
# 1. Setup iniziale staging
./install.sh staging
./platform.sh up staging

# 2. Accedi UI e genera API key
open http://localhost:5679
# Settings → API → Generate

# 3. Aggiungi API key
nano environments/staging/.env
# N8N_API_KEY=...

# 4. Ora le migrazioni funzionano
git pull
./platform.sh migrate staging
```

## Security Notes

- **MAI** committare `N8N_API_KEY` in git
- Aggiungi in `.gitignore`: `environments/*/.env`
- Rigenera key se compromessa
- Usa key diverse per ogni ambiente

## Riferimenti

- [n8n API Documentation](https://docs.n8n.io/api/)
- [n8n Authentication](https://docs.n8n.io/hosting/authentication/)
