# N8N Workflows

Questa directory contiene i workflows n8n versionati in formato JSON.

## Naming Convention

```
NNN_workflow_name.json
```

Dove:
- `NNN` = numero sequenziale a 3 cifre (001, 002, 003...)
- `workflow_name` = nome workflow con underscore

## Esportazione Workflows

### Via UI

1. Apri n8n: http://localhost:5678
2. Apri workflow da esportare
3. Click menu "..." → Export
4. Salva come `migrations/n8n/workflows/NNN_name.json`

### Via API

```bash
# Lista workflows
curl -u admin:password http://localhost:5678/api/v1/workflows

# Esporta singolo workflow
curl -u admin:password http://localhost:5678/api/v1/workflows/1 | \
  jq '.' > migrations/n8n/workflows/002_my_workflow.json
```

## Best Practices

### 1. Rimuovi Dati Sensibili

Prima di committare, verifica che non ci siano:
- API keys
- Passwords
- Tokens
- URL privati

```bash
# Cerca dati sensibili
grep -i "password\|api_key\|token\|secret" migrations/n8n/workflows/*.json
```

### 2. Usa Environment Variables

In n8n, usa variabili d'ambiente per dati sensibili:

```json
{
  "parameters": {
    "url": "={{$env.API_URL}}",
    "authentication": {
      "apiKey": "={{$env.API_KEY}}"
    }
  }
}
```

### 3. Versionamento

Ogni modifica significativa = nuovo file:

```
001_initial_workflow.json
002_add_error_handling.json
003_optimize_performance.json
```

### 4. Testing

Testa workflows in dev prima di applicare ad altri ambienti:

```bash
# Importa in dev
./platform.sh migrate dev

# Testa workflow manualmente in n8n UI
# Verifica logs
./platform.sh logs dev n8n
```

## Struttura Workflow Tipo

```json
{
  "name": "My Workflow Name",
  "nodes": [
    {
      "parameters": {},
      "id": "uuid-here",
      "name": "Start",
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [250, 300]
    },
    {
      "parameters": {
        "url": "={{$env.API_URL}}"
      },
      "id": "uuid-here",
      "name": "HTTP Request",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.1,
      "position": [450, 300]
    }
  ],
  "connections": {
    "Start": {
      "main": [
        [
          {
            "node": "HTTP Request",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "active": false,
  "settings": {
    "executionOrder": "v1"
  },
  "tags": [
    {
      "name": "production",
      "id": "1"
    }
  ]
}
```

## Applicazione Workflows

```bash
# Applica tutti i workflows pending
./platform.sh migrate dev

# Il sistema importa solo workflows non ancora presenti
```

## Gestione Credenziali

Le credenziali NON sono esportate nei workflows. Gestiscile separatamente:

### Opzione 1: Manuale

1. Crea credenziali in n8n UI
2. Documenta in `migrations/n8n/credentials/README.md`

### Opzione 2: Environment Variables

Usa variabili d'ambiente in `.env`:

```bash
# environments/dev/.env
N8N_CUSTOM_API_KEY=your-key-here
N8N_CUSTOM_WEBHOOK_URL=https://example.com
```

Referenzia in workflow:

```json
{
  "parameters": {
    "authentication": {
      "apiKey": "={{$env.N8N_CUSTOM_API_KEY}}"
    }
  }
}
```

## Troubleshooting

### Workflow non si importa

```bash
# Verifica JSON valido
cat migrations/n8n/workflows/002_workflow.json | jq '.'

# Verifica n8n disponibile
curl -u admin:password http://localhost:5678/healthz

# Controlla logs
./platform.sh logs dev n8n
```

### Credenziali mancanti

1. Verifica che workflow usi credenziali esistenti
2. Oppure crea credenziali in n8n UI
3. Aggiorna workflow per usare credenziali corrette

### Nodi obsoleti

Se workflow usa nodi vecchi:

1. Apri in n8n UI
2. Aggiorna nodi
3. Ri-esporta come nuova versione

## Workflow Patterns

### Pattern 1: Scheduled Job

```json
{
  "name": "Daily Sync Job",
  "nodes": [
    {
      "parameters": {
        "rule": {
          "interval": [{"field": "cronExpression", "expression": "0 2 * * *"}]
        }
      },
      "type": "n8n-nodes-base.scheduleTrigger"
    }
  ]
}
```

### Pattern 2: Webhook Trigger

```json
{
  "nodes": [
    {
      "parameters": {
        "path": "webhook-path",
        "httpMethod": "POST"
      },
      "type": "n8n-nodes-base.webhook"
    }
  ]
}
```

### Pattern 3: Error Handling

```json
{
  "nodes": [
    {
      "parameters": {
        "mode": "catchAll"
      },
      "type": "n8n-nodes-base.errorTrigger",
      "name": "Error Handler"
    }
  ]
}
```

## Checklist Pre-Produzione

Prima di applicare in produzione:

- [ ] Testato in dev
- [ ] Testato in staging
- [ ] Credenziali configurate
- [ ] Environment variables impostate
- [ ] Nessun dato sensibile nel JSON
- [ ] Documentazione aggiornata
- [ ] Team notificato

## Esempi

Vedi file esistenti:
- `001_example_workflow.json` - Esempio base con HTTP request
