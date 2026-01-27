# Using Local Platform Kit as Template

Guida per usare questo repository come template per nuovi progetti.

## 🎯 Quando Usare Questo Template

Usa questo template quando devi creare un nuovo progetto con:
- ✅ Dev environment in **Supabase Cloud + n8n Cloud** (managed)
- ✅ Staging/Prod in **self-hosted** (su tuoi server)
- ✅ Sistema di migrazioni versionato
- ✅ Backup automatici
- ✅ Multi-environment management

---

## 📦 METODO 1: GitHub Template (Consigliato)

### Step 1: Setup Template Repository (Una Volta)

```bash
# 1. Pushes questo repository su GitHub
cd local-platform-kit
git remote add origin https://github.com/TUO-USERNAME/local-platform-kit.git
git branch -M main
git push -u origin main

# 2. Su GitHub: Settings → Template repository ✅
```

### Step 2: Creare Nuovo Progetto

Per ogni nuovo progetto:

**Su GitHub**:
1. Vai al tuo template: `github.com/TUO-USERNAME/local-platform-kit`
2. Click: **"Use this template"** → **"Create a new repository"**
3. Nome: `my-new-project`
4. Create repository

**Sul Tuo Computer**:

```bash
# Clone del nuovo progetto
git clone https://github.com/TUO-USERNAME/my-new-project.git
cd my-new-project

# Inizializza progetto (pulisce esempi, configura)
./init-project.sh

# Segui il wizard:
# - Project name: my-new-project
# - Description: My awesome SaaS
# - Remove examples? Yes
# - Initialize git? Yes (già fatto)
```

**Output**:
```
✓ Example migrations cleaned
✓ Environment directories cleaned
✓ README.md updated
✓ Git initialized

Next Steps:
1. Setup Development Environment:
   ./install.sh dev

2. Start Services:
   ./platform.sh up dev

3. Configure Dev Cloud Sync:
   ./scripts/sync-from-dev-cloud.sh
```

---

## 📦 METODO 2: Clone Manuale

Se non vuoi usare GitHub template:

```bash
# 1. Clone template
git clone https://github.com/TUO-USERNAME/local-platform-kit.git my-new-project
cd my-new-project

# 2. Rimuovi git history del template
rm -rf .git

# 3. Inizializza nuovo progetto
./init-project.sh

# 4. Crea nuovo repository
git remote add origin https://github.com/TUO-USERNAME/my-new-project.git
git push -u origin main
```

---

## 🚀 SETUP PROGETTO NUOVO

Dopo aver creato il progetto dal template:

### 1. Setup Dev Environment (Locale)

```bash
# Installa dipendenze locali per test
./install.sh dev

# Avvia servizi
./platform.sh up dev

# Accedi:
# - n8n: http://localhost:5678
# - Supabase: http://localhost:3000
```

### 2. Configura Sync con Dev Cloud

```bash
# Configura credenziali del tuo dev cloud
./scripts/sync-from-dev-cloud.sh

# Ti chiederà:
# - Supabase Host: db.xxx.supabase.co
# - Password: ***
# - n8n URL: https://xxx.app.n8n.cloud
# - n8n API Key: ***

# Poi export migrazioni esistenti (se ce ne sono)
```

### 3. Setup Staging (Su Server Staging)

```bash
# SSH su staging server
ssh user@staging-server

# Clone progetto
git clone https://github.com/TUO-USERNAME/my-new-project.git
cd my-new-project

# Setup staging
./install.sh staging

# Avvia
./platform.sh up staging

# Applica migrazioni (se ci sono)
./platform.sh migrate staging
```

### 4. Setup Prod (Su Server Prod)

```bash
# SSH su prod server
ssh user@prod-server

# Clone progetto
git clone https://github.com/TUO-USERNAME/my-new-project.git
cd my-new-project

# Setup prod
./install.sh prod

# Avvia
./platform.sh up prod

# Applica migrazioni
./platform.sh migrate prod
```

---

## 📂 STRUTTURA POST-INIZIALIZZAZIONE

Dopo `./init-project.sh`:

```
my-new-project/
├── README.md                    # ✨ Aggiornato con nome progetto
├── .project.json                # ✨ Nuovo - Config progetto
├── .examples/                   # ✨ Nuovo - Backup esempi template
│   ├── migrations/
│   └── README.original.md
├── migrations/
│   ├── supabase/
│   │   └── README.md           # ✨ Pulito - Pronto per tue migrations
│   └── n8n/
│       └── workflows/
│           └── README.md       # ✨ Pulito
├── environments/
│   ├── dev/                    # ✨ Pulito
│   ├── staging/                # ✨ Pulito
│   └── prod/                   # ✨ Pulito
└── [resto invariato]
```

**Cosa è cambiato**:
- ✅ Migrazioni esempio rimosse (backup in `.examples/`)
- ✅ Environments puliti
- ✅ README personalizzato con nome progetto
- ✅ `.project.json` con metadata progetto
- ✅ Git reinizialized (opzionale)

---

## 🔄 WORKFLOW NORMALE DEL PROGETTO

### Sviluppo

```bash
# 1. Lavori in dev cloud (Supabase + n8n managed)

# 2. Export migrazioni (sul tuo PC)
cd my-new-project
./scripts/sync-from-dev-cloud.sh
# → Crea SQL migrations
# → Export workflows
# → Git commit & push

# 3. Deploy staging
ssh staging
cd my-new-project
git pull
./platform.sh migrate staging

# 4. Deploy prod (quando OK)
ssh prod
cd my-new-project
git pull
./platform.sh backup prod  # PRIMA backup!
./platform.sh migrate prod
```

Vedi [WORKFLOW.md](WORKFLOW.md) per dettagli.

---

## 📚 FILE DA PERSONALIZZARE

Dopo inizializzazione, personalizza:

### 1. README.md
- Già aggiornato da `init-project.sh`
- Aggiungi dettagli specifici progetto
- Link repository
- Istruzioni team

### 2. docker-compose.yml (opzionale)
Se hai bisogno di servizi custom:

```yaml
services:
  # Aggiungi servizi custom
  redis:
    image: redis:alpine
    profiles: ["dev"]
```

### 3. .env.example (opzionale)
Aggiungi variabili custom:

```bash
# Custom variables per il tuo progetto
MY_API_KEY=changeme
MY_CUSTOM_CONFIG=value
```

### 4. DEPLOYMENT.md
Aggiungi dettagli specifici:
- Server IP/hostname
- DNS configuration
- SSL certificates
- Monitoring setup

---

## 🎨 BEST PRACTICES

### 1. **Un Progetto = Un Repository**

Ogni progetto ha il suo repository separato:

```
github.com/TUO-USERNAME/
├── local-platform-kit/          ← Template (una volta)
├── saas-app-1/                  ← Progetto 1 (dal template)
├── saas-app-2/                  ← Progetto 2 (dal template)
└── client-project/              ← Progetto 3 (dal template)
```

### 2. **Template Centrale Aggiornato**

Quando aggiorni il template con nuove features:

```bash
cd local-platform-kit
git pull
git push

# I progetti esistenti possono fare cherry-pick se serve:
cd my-old-project
git remote add template https://github.com/TUO-USERNAME/local-platform-kit.git
git fetch template
git cherry-pick <commit-hash>  # Solo feature specifiche
```

### 3. **Documentazione Specifica**

Ogni progetto dovrebbe documentare:
- Setup unico del progetto
- API keys necessarie
- Integrazioni esterne
- Deployment specifici
- Team contacts

### 4. **Backup Strategy**

```bash
# Per ogni progetto in prod
./platform.sh backup prod

# Schedule diversi per progetto se necessario
# environments/prod/.env
BACKUP_SCHEDULE="0 3 * * *"  # 3 AM per progetto A
BACKUP_SCHEDULE="0 4 * * *"  # 4 AM per progetto B
```

---

## 🔧 PERSONALIZZAZIONI COMUNI

### Cambiare Porte Default

Se hai multipli progetti sulla stessa macchina:

```bash
# Progetto 1
nano environments/dev/.env
N8N_PORT=5678
SUPABASE_KONG_HTTP_PORT=8000

# Progetto 2 (sulla stessa macchina)
N8N_PORT=5778
SUPABASE_KONG_HTTP_PORT=8100
```

### Aggiungere Servizi Custom

```yaml
# docker-compose.yml
services:
  # Servizio custom per questo progetto
  redis:
    image: redis:alpine
    profiles: ["n8n"]  # Avvia solo con n8n
    networks:
      - platform-network
```

### Custom Scripts

```bash
# scripts/custom/
# Aggiungi script specifici del progetto

./scripts/custom/seed-database.sh
./scripts/custom/generate-types.sh
```

---

## ❓ FAQ

### Q: Devo ricreare tutto per ogni progetto?
**A**: No! Usi il template che hai già configurato. GitHub template o clone diretto.

### Q: Posso aggiornare progetti vecchi con nuove feature del template?
**A**: Sì, con git cherry-pick selettivo o merge manuale.

### Q: Multipli progetti stesso server?
**A**: Sì, usa porte diverse. Vedi "Personalizzazioni".

### Q: Come gestisco credenziali multiple progetti?
**A**: Ogni progetto ha il suo `.env` separato. Mai committare!

### Q: Database separato per progetto?
**A**: Sì! Ogni progetto ha i suoi container Docker isolati.

---

## 📞 Supporto

**Template Issues**: https://github.com/TUO-USERNAME/local-platform-kit/issues
**Progetto Issues**: Nel repository del progetto specifico

---

## 🎯 CHECKLIST NUOVO PROGETTO

Quando inizi nuovo progetto:

- [ ] Crea da template GitHub (o clone)
- [ ] Esegui `./init-project.sh`
- [ ] Push su repository progetto
- [ ] Setup dev local: `./install.sh dev`
- [ ] Configura sync cloud: `./scripts/sync-from-dev-cloud.sh`
- [ ] Clone su staging server
- [ ] Setup staging: `./install.sh staging`
- [ ] Clone su prod server
- [ ] Setup prod: `./install.sh prod`
- [ ] Documenta credentials necessarie
- [ ] Configura backup automatici
- [ ] Setup monitoring (opzionale)
- [ ] Briefing team su workflow

---

**Ready to build! 🚀**
