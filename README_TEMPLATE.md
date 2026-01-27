# Local Platform Kit 🚀

**Template repository** per progetti con Supabase + n8n: dev in cloud, staging/prod self-hosted.

> Sistema completo e modulare per gestire **Supabase self-hosted**, **n8n** e **backup automatici** con workflow di sviluppo professionale.

## 🎯 Cos'è?

Local Platform Kit è un **template/boilerplate** che fornisce:

- ✅ **Multi-environment**: Dev cloud, Staging/Prod self-hosted
- ✅ **Sistema di migrazioni** versionato (SQL + JSON workflows)
- ✅ **Backup automatici** con supporto locale e Google Drive
- ✅ **Docker Compose** con profiles modulari
- ✅ **Scripts professionali** per gestione completa
- ✅ **CI/CD ready** per deployment automatizzato

## 🏗️ Architettura

```
┌─────────────────────┐
│   DEV (Cloud)       │  ← Sviluppi qui (managed)
│  Supabase + n8n     │
└──────────┬──────────┘
           │
           │ Export & versiona migrazioni
           ↓
┌─────────────────────┐
│  GIT REPOSITORY     │  ← Questo template
│  migrations/        │
└──────────┬──────────┘
           │
           ├─ git pull → STAGING (Self-hosted)
           └─ git pull → PROD (Self-hosted)
```

## ⚡ Quick Start

### Per Nuovo Progetto

```bash
# 1. Usa come template GitHub
# Vai su github.com/TUO-USERNAME/local-platform-kit
# Click "Use this template" → Create repository

# 2. Clone nuovo progetto
git clone https://github.com/TUO-USERNAME/my-new-project.git
cd my-new-project

# 3. Inizializza (pulisce esempi, configura)
./init-project.sh

# 4. Setup dev
./install.sh dev
./platform.sh up dev

# 5. Configura sync da dev cloud
./scripts/sync-from-dev-cloud.sh
```

**Vedi [TEMPLATE_USAGE.md](TEMPLATE_USAGE.md) per guida completa.**

---

## 📚 Documentazione

| Documento | Descrizione |
|-----------|-------------|
| **[TEMPLATE_USAGE.md](TEMPLATE_USAGE.md)** | 🎯 **START HERE** - Come usare come template |
| **[QUICKSTART.md](QUICKSTART.md)** | Setup rapido in 5 minuti |
| **[WORKFLOW.md](WORKFLOW.md)** | Workflow sviluppo completo |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Architettura tecnica dettagliata |
| **[DEPLOYMENT.md](DEPLOYMENT.md)** | Checklist produzione |
| **[MIGRATION_CLOUD_TO_LOCAL.md](MIGRATION_CLOUD_TO_LOCAL.md)** | Migrazione da cloud esistente |
| **[CONTRIBUTING.md](CONTRIBUTING.md)** | Contribuire al template |

---

## 🎨 Features

### Sistema di Migrazioni

```bash
# Export da dev cloud
./scripts/sync-from-dev-cloud.sh
# → Genera SQL versionati
# → Export workflows n8n
# → Git commit & push

# Deploy su staging/prod
git pull
./platform.sh migrate <env>
```

### Backup Automatici

- Schedulazione via cron configurabile
- Supporto locale + Google Drive (rclone)
- Retention policy
- Restore con auto-detection

### Multi-Environment

- **Dev**: Cloud managed (Supabase + n8n)
- **Staging**: Self-hosted (porte 5679, 8001, 3001)
- **Prod**: Self-hosted (porte 5680, 8002, 3002)

Ogni ambiente completamente isolato.

### Scripts Professionali

- `platform.sh`: 10+ comandi per gestione lifecycle
- `install.sh`: Wizard interattivo setup
- `sync-from-dev-cloud.sh`: Export automatico migrazioni
- Logging colorato, error handling, health checks

---

## 🚀 Comandi Principali

```bash
# ====================================
# LIFECYCLE
# ====================================
./platform.sh up <env>       # Avvia servizi
./platform.sh down <env>     # Ferma servizi
./platform.sh restart <env>  # Riavvia
./platform.sh status <env>   # Stato containers

# ====================================
# MIGRAZIONI
# ====================================
./scripts/sync-from-dev-cloud.sh  # Export da cloud
./platform.sh migrate <env>       # Applica migrazioni
./platform.sh state <env>         # Mostra stato

# ====================================
# MONITORING
# ====================================
./platform.sh health <env>   # Health check completo
./platform.sh logs <env>     # Visualizza logs

# ====================================
# BACKUP
# ====================================
./platform.sh backup <env>         # Backup manuale
./platform.sh restore <env> <file> # Ripristina
```

---

## 📦 Stack Tecnologico

- **Docker Compose v2** con profiles
- **PostgreSQL 15** (Supabase fork + standard)
- **Supabase** self-hosted stack completo
- **n8n** latest per automation
- **Kong** API Gateway
- **rclone** per backup cloud

---

## 🎯 Use Cases

Perfetto per:

- ✅ SaaS applications
- ✅ Internal tools
- ✅ Client projects
- ✅ Prototypes → Production
- ✅ Team collaboration
- ✅ Agency projects

**Non adatto per**:

- ❌ Progetti senza Supabase/n8n
- ❌ Cloud-only deployments
- ❌ Kubernetes environments (usa fork custom)

---

## 🔧 Personalizzazione

Dopo `./init-project.sh`, puoi personalizzare:

- `docker-compose.yml` - Aggiungi servizi custom
- `.env.example` - Variabili custom
- `scripts/` - Script specifici progetto
- Porte, network, volumi

Vedi [TEMPLATE_USAGE.md](TEMPLATE_USAGE.md) per esempi.

---

## 🤝 Contribuire al Template

Migliorie al template sono benvenute!

```bash
# Fork del template
git clone https://github.com/TUO-USERNAME/local-platform-kit.git
cd local-platform-kit

# Crea branch feature
git checkout -b feature/my-improvement

# Commit & PR
git commit -m "feat: add my improvement"
git push origin feature/my-improvement
```

Vedi [CONTRIBUTING.md](CONTRIBUTING.md) per guidelines.

---

## 📊 Progetti che Usano Questo Template

Lista di progetti pubblici che usano Local Platform Kit:

- [Add your project here via PR!]

---

## 📄 License

MIT License - Usa liberamente per progetti commerciali e open source.

---

## 🆘 Support

- **Template Issues**: [GitHub Issues](https://github.com/TUO-USERNAME/local-platform-kit/issues)
- **Documentation**: [Wiki](https://github.com/TUO-USERNAME/local-platform-kit/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/TUO-USERNAME/local-platform-kit/discussions)

---

## 🌟 Roadmap

- [ ] GitHub Actions templates per CI/CD
- [ ] Kubernetes support (helm charts)
- [ ] Monitoring stack integrato (Prometheus + Grafana)
- [ ] Automated testing framework
- [ ] Multi-cloud backup support (AWS S3, Azure Blob)
- [ ] Web UI per management
- [ ] Docker Swarm support

---

## 🙏 Credits

Built with:
- [Supabase](https://supabase.com) - Open source Firebase alternative
- [n8n](https://n8n.io) - Workflow automation
- [Docker](https://docker.com) - Containerization
- [PostgreSQL](https://postgresql.org) - Database

---

## ⭐ Star History

Se questo template ti è utile, lascia una ⭐!

---

**Made with ❤️ for DevOps Engineers**

Start your next project in minutes, not days! 🚀
