# Come Usare per Nuovi Progetti

**Risposta veloce**: Sì, per ogni progetto nuovo duplichi questa repo come template.

## 🎯 Risposta alla Tua Domanda

> "Ogni volta che avvio un progetto nuovo cosa devo fare? Devo avviare una nuova repo dove duplico questa repo?"

**SÌ, esatto!** Questo è un **template** che usi per ogni nuovo progetto.

---

## 🚀 PROCEDURA VELOCE

### Opzione 1: GitHub Template (Più Facile)

```bash
# 1. Setup una volta (pusha questo template su GitHub)
cd local-platform-kit
git remote add origin https://github.com/TUO-USERNAME/local-platform-kit.git
git push -u origin main

# 2. Su GitHub: Settings → ✅ Template repository

# 3. Per ogni NUOVO progetto:
#    - GitHub: "Use this template" → Create repository
#    - Nome: my-new-project

# 4. Clone e inizializza
git clone https://github.com/TUO-USERNAME/my-new-project.git
cd my-new-project
./init-project.sh  # Pulisce esempi, configura progetto
```

### Opzione 2: Clone Manuale

```bash
# Per ogni nuovo progetto:
git clone https://github.com/TUO-USERNAME/local-platform-kit.git my-new-project
cd my-new-project
rm -rf .git
./init-project.sh
git init
git remote add origin https://github.com/TUO-USERNAME/my-new-project.git
git push -u origin main
```

---

## 📂 ORGANIZZAZIONE REPOSITORY

```
GitHub Account
├── local-platform-kit/          ← Template (UNA VOLTA)
├── saas-app-1/                  ← Progetto 1 (dal template)
├── saas-app-2/                  ← Progetto 2 (dal template)
└── client-project-x/            ← Progetto 3 (dal template)
```

**Ogni progetto** = **Repository separato** con la sua copia del template.

---

## 🔄 WORKFLOW COMPLETO

### 1. Setup Template (Una Volta)

```bash
# Configura il template su GitHub
cd local-platform-kit
git remote add origin https://github.com/TUO-USERNAME/local-platform-kit.git
git push -u origin main

# Marca come template su GitHub
# Settings → ✅ Template repository
```

### 2. Nuovo Progetto (Ogni Volta)

```bash
# A. Crea da template GitHub
# "Use this template" → my-saas-app

# B. Clone e inizializza
git clone https://github.com/TUO-USERNAME/my-saas-app.git
cd my-saas-app
./init-project.sh

# Output:
# ✓ Example migrations cleaned
# ✓ Environments cleaned
# ✓ README updated with project name
# ✓ Git initialized

# C. Sviluppo normale
./install.sh dev          # Setup dev local
./platform.sh up dev      # Test locale

# D. Sync da dev cloud
./scripts/sync-from-dev-cloud.sh
# → Export SQL migrations
# → Export n8n workflows
# → Git commit & push
```

### 3. Deploy Staging/Prod

```bash
# Su server staging
git clone https://github.com/TUO-USERNAME/my-saas-app.git
cd my-saas-app
./install.sh staging
./platform.sh up staging

# Ogni deploy nuovo:
git pull
./platform.sh migrate staging

# Stesso per prod
```

---

## 🎨 COSA FA `./init-project.sh`

Quando esegui `./init-project.sh` su una nuova copia del template:

```
Before:
my-new-project/
├── migrations/
│   ├── supabase/
│   │   ├── 001_init_schema.sql        ← Esempi del template
│   │   └── 002_add_projects.sql       ← Esempi del template
│   └── n8n/
│       └── 001_example_workflow.json  ← Esempi del template
└── README.md                          ← README generico template

After ./init-project.sh:
my-new-project/
├── migrations/
│   ├── supabase/
│   │   └── README.md                  ← Pulito, pronto per tue migrations
│   └── n8n/
│       └── README.md                  ← Pulito, pronto per tuoi workflows
├── .examples/
│   └── migrations/                    ← Backup esempi (reference)
├── README.md                          ← Aggiornato con nome progetto!
└── .project.json                      ← Nuovo - metadata progetto
```

**Risultato**: Template pulito, pronto per il tuo progetto specifico!

---

## 💡 CONCETTI CHIAVE

### 1. Template = Boilerplate

Questo repository è come uno "starter kit":
- Configuri **UNA VOLTA**
- Riusi per **OGNI NUOVO PROGETTO**
- Ogni progetto diventa indipendente

### 2. Un Progetto = Un Repository

```
Template:  local-platform-kit (master)
           ↓ use as template
Projects:  ├── saas-app-1 (independent repo)
           ├── saas-app-2 (independent repo)
           └── client-project (independent repo)
```

Ogni progetto ha:
- ✅ Repository Git separato
- ✅ Migrazioni separate
- ✅ Environments separati
- ✅ Configurazioni separate

### 3. Dev Cloud → Self-hosted

Per ogni progetto:
- **Dev**: Cloud managed (Supabase + n8n)
- **Staging/Prod**: Self-hosted (con questo kit)

---

## 📊 ESEMPIO PRATICO

### Scenario: 3 Progetti SaaS

```bash
# ==================================
# PROGETTO 1: E-commerce Platform
# ==================================

# GitHub: Use template → ecommerce-platform
git clone https://github.com/me/ecommerce-platform.git
cd ecommerce-platform
./init-project.sh
# Project name: ecommerce-platform
# Description: Multi-vendor marketplace

# Sviluppo:
./scripts/sync-from-dev-cloud.sh  # Export migrations da dev cloud
git push

# Deploy staging/prod con git pull + migrate

# ==================================
# PROGETTO 2: CRM System
# ==================================

# GitHub: Use template → crm-system
git clone https://github.com/me/crm-system.git
cd crm-system
./init-project.sh
# Project name: crm-system
# Description: Customer relationship management

# Stesso workflow...

# ==================================
# PROGETTO 3: Analytics Dashboard
# ==================================

# GitHub: Use template → analytics-dashboard
# ...stesso processo
```

**Risultato**: 3 progetti completamente indipendenti, ognuno con:
- Repository separato
- Migrazioni separate
- Deploy separati
- Ma stesso workflow efficiente!

---

## ✅ CHECKLIST NUOVO PROGETTO

Quando inizi nuovo progetto:

**Setup (10 minuti)**:
- [ ] GitHub: "Use this template" → nuovo repo
- [ ] Clone locale
- [ ] `./init-project.sh`
- [ ] `./install.sh dev` (test locale)
- [ ] `./scripts/sync-from-dev-cloud.sh` (configura sync)

**Deploy Staging (15 minuti)**:
- [ ] SSH su staging server
- [ ] Clone progetto
- [ ] `./install.sh staging`
- [ ] `./platform.sh up staging`
- [ ] Configura credenziali n8n

**Deploy Prod (15 minuti)**:
- [ ] SSH su prod server
- [ ] Clone progetto
- [ ] `./install.sh prod`
- [ ] `./platform.sh up prod`
- [ ] Configura credenziali n8n
- [ ] Test backup

**Totale: ~40 minuti** per nuovo progetto completo!

---

## 🔄 AGGIORNARE TEMPLATE

Se aggiungi features al template:

```bash
# Template repository
cd local-platform-kit
# ... aggiungi features ...
git commit -m "feat: add new feature"
git push

# Progetti esistenti possono:
# 1. Cherry-pick feature specifica
cd my-old-project
git remote add template https://github.com/me/local-platform-kit.git
git fetch template
git cherry-pick <commit>

# 2. O merge selettivo manuale
```

---

## 📚 DOCUMENTAZIONE CORRELATA

- **[TEMPLATE_USAGE.md](TEMPLATE_USAGE.md)** - Guida completa template
- **[WORKFLOW.md](WORKFLOW.md)** - Workflow sviluppo quotidiano
- **[QUICKSTART.md](QUICKSTART.md)** - Setup rapido
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deployment produzione

---

## 🎯 TL;DR

**Domanda**: "Devo duplicare la repo per ogni progetto?"

**Risposta**: **SÌ!**

```bash
# 1. Template su GitHub (una volta)
# 2. Per ogni nuovo progetto:
#    - "Use this template"
#    - ./init-project.sh
#    - Lavora normalmente
# 3. Ogni progetto è indipendente
```

**È come**:
- Create React App → ogni progetto nuovo
- Rails new → ogni progetto nuovo
- Local Platform Kit → ogni progetto nuovo ✅

---

**Ready to start your next project! 🚀**
