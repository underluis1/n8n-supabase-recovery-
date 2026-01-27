# Deployment Guide - Production Checklist

Guida completa per deployment in produzione di Local Platform Kit.

## Pre-Deployment Checklist

### Infrastruttura

- [ ] Server Linux (Ubuntu 20.04+ consigliato)
- [ ] Docker >= 20.10 installato
- [ ] Docker Compose v2 installato
- [ ] jq installato (`sudo apt-get install jq`)
- [ ] Disk space sufficiente (minimo 50GB, raccomandato 100GB+)
- [ ] RAM minima 4GB (raccomandato 8GB+)
- [ ] CPU 2+ cores
- [ ] Backup storage configurato (locale o cloud)

### Networking

- [ ] Firewall configurato
  - SSH (22) da IP autorizzati
  - HTTP (80/443) se servizi pubblici
  - Tutte le altre porte chiuse
- [ ] Reverse proxy se necessario (Nginx/Traefik)
- [ ] SSL certificates (Let's Encrypt)
- [ ] DNS configurato
- [ ] VPN setup se accesso remoto

### Security

- [ ] Sistema operativo aggiornato
- [ ] User non-root creato per Docker
- [ ] SSH key-based authentication
- [ ] Fail2ban installato
- [ ] Unattended upgrades abilitato
- [ ] Firewall UFW/iptables configurato

## Installation Steps

### 1. Clone Repository

```bash
# Come utente non-root
cd ~
git clone <repo-url> local-platform-kit
cd local-platform-kit
```

### 2. Setup Permissions

```bash
chmod +x install.sh platform.sh
chmod +x scripts/**/*.sh
chmod +x docker/backup/*.sh
```

### 3. Configure Production Environment

```bash
./install.sh prod
```

Durante l'installazione:
- Seleziona servizi necessari
- Abilita backup automatici
- Configura Google Drive se necessario

### 4. Review Configuration

```bash
nano environments/prod/.env
```

**Variabili critiche da modificare**:

```bash
# Cambia TUTTI i secrets!
N8N_ENCRYPTION_KEY=<genera nuovo: openssl rand -base64 32>
N8N_DB_POSTGRESDB_PASSWORD=<genera nuovo>
POSTGRES_PASSWORD=<genera nuovo>
JWT_SECRET=<genera nuovo: openssl rand -base64 32>

# Cambia credentials
N8N_BASIC_AUTH_USER=admin_prod
N8N_BASIC_AUTH_PASSWORD=<strong password>

# URL pubblici se reverse proxy
SUPABASE_PUBLIC_URL=https://api.tuodominio.com
N8N_PROTOCOL=https

# Backup
BACKUP_ENABLED=true
BACKUP_SCHEDULE="0 3 * * *"  # 3 AM
BACKUP_RETENTION_DAYS=90
BACKUP_GDRIVE_ENABLED=true
```

### 5. Secure .env File

```bash
chmod 600 environments/prod/.env
```

### 6. Generate New JWT Keys

Per Supabase, genera nuovi JWT keys invece di usare quelli di default:

```bash
# Usa lo script di Supabase
curl -L https://supabase.com/docs/guides/self-hosting/docker | \
  grep -A 100 "Generate JWT" | \
  bash
```

Aggiorna `ANON_KEY` e `SERVICE_ROLE_KEY` in `.env`.

### 7. Start Services

```bash
./platform.sh up prod
```

### 8. Verify Health

```bash
./platform.sh health prod
./platform.sh status prod
```

### 9. Apply Migrations

```bash
./platform.sh migrate prod
```

### 10. Configure Backup

Se Google Drive:

```bash
# Entra nel container
docker exec -it platform-prod-backup bash

# Configura rclone
rclone config

# Exit e copia config
exit
docker cp platform-prod-backup:/root/.config/rclone/rclone.conf \
  docker/backup/rclone/rclone.conf

chmod 600 docker/backup/rclone/rclone.conf
```

### 11. Test Backup

```bash
./platform.sh backup prod
```

Verifica:
- File creati in `backups/`
- File uploadati su Google Drive (se abilitato)

### 12. Test Restore

**ATTENZIONE**: Usa database di test!

```bash
# Setup ambiente test
./install.sh test
./platform.sh up test

# Restore backup prod in test
./platform.sh restore test backups/supabase/latest.sql.gz

# Verifica dati
# ...

# Cleanup
./platform.sh clean test
```

## Post-Deployment

### Monitoring Setup

#### 1. Log Monitoring

```bash
# Setup logrotate
sudo nano /etc/logrotate.d/docker-platform

# Contenuto:
/var/lib/docker/containers/*/*.log {
  daily
  rotate 7
  compress
  delaycompress
  missingok
  notifempty
  copytruncate
}
```

#### 2. Disk Space Monitoring

```bash
# Script di check
cat > ~/check-disk.sh << 'EOF'
#!/bin/bash
THRESHOLD=80
USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

if [ $USAGE -gt $THRESHOLD ]; then
    echo "ALERT: Disk usage at ${USAGE}%"
    # Invia alert (email, Slack, etc.)
fi
EOF

chmod +x ~/check-disk.sh

# Cron ogni ora
(crontab -l 2>/dev/null; echo "0 * * * * ~/check-disk.sh") | crontab -
```

#### 3. Service Monitoring

```bash
# Script di health check
cat > ~/check-health.sh << 'EOF'
#!/bin/bash
cd ~/local-platform-kit

if ! ./platform.sh health prod > /dev/null 2>&1; then
    echo "ALERT: Health check failed"
    # Invia alert
fi
EOF

chmod +x ~/check-health.sh

# Cron ogni 5 minuti
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/check-health.sh") | crontab -
```

### Backup Verification

```bash
# Setup verifica backup giornaliera
cat > ~/verify-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR=~/local-platform-kit/backups
TODAY=$(date +%Y%m%d)

# Verifica esistenza backup odierno
if ! find $BACKUP_DIR -name "*${TODAY}*.sql.gz" | grep -q .; then
    echo "ALERT: No backup found for today"
    # Invia alert
fi
EOF

chmod +x ~/verify-backup.sh

# Cron ogni giorno alle 4 AM (dopo backup delle 3 AM)
(crontab -l 2>/dev/null; echo "0 4 * * * ~/verify-backup.sh") | crontab -
```

### Security Hardening

#### 1. Firewall Rules

```bash
# UFW esempio
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

#### 2. Fail2ban

```bash
sudo apt-get install fail2ban

# Config base
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
```

```bash
sudo systemctl restart fail2ban
```

#### 3. Auto-Updates

```bash
sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Documentation

- [ ] Documenta URL di accesso
- [ ] Documenta credenziali (password manager)
- [ ] Documenta procedura di restore
- [ ] Documenta contatti per emergenze
- [ ] Crea runbook per common issues

## Reverse Proxy Setup (Nginx)

Se esponi servizi pubblicamente:

### Install Nginx

```bash
sudo apt-get install nginx certbot python3-certbot-nginx
```

### Configure n8n

```nginx
# /etc/nginx/sites-available/n8n
server {
    listen 80;
    server_name n8n.tuodominio.com;

    location / {
        proxy_pass http://localhost:5680;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Configure Supabase

```nginx
# /etc/nginx/sites-available/supabase
server {
    listen 80;
    server_name api.tuodominio.com;

    location / {
        proxy_pass http://localhost:8002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    listen 80;
    server_name studio.tuodominio.com;

    location / {
        proxy_pass http://localhost:3002;
        proxy_set_header Host $host;
    }
}
```

### Enable Sites

```bash
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/supabase /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### SSL with Let's Encrypt

```bash
sudo certbot --nginx -d n8n.tuodominio.com
sudo certbot --nginx -d api.tuodominio.com
sudo certbot --nginx -d studio.tuodominio.com
```

### Auto-Renewal

```bash
# Test renewal
sudo certbot renew --dry-run

# Cron già configurato da certbot
```

## Disaster Recovery Plan

### Scenario 1: Data Corruption

```bash
# Stop services
./platform.sh down prod

# Restore from latest backup
./platform.sh restore prod backups/latest.sql.gz

# Start services
./platform.sh up prod

# Verify
./platform.sh health prod
```

### Scenario 2: Complete Server Failure

```bash
# New server
# 1. Setup infrastruttura (OS, Docker, etc.)
# 2. Clone repository
cd ~ && git clone <repo-url> local-platform-kit
cd local-platform-kit

# 3. Restore .env
scp old-server:~/local-platform-kit/environments/prod/.env \
    environments/prod/.env

# 4. Download backup
# Da Google Drive o storage remoto
rclone copy gdrive:/platform-backups/prod/ backups/

# 5. Start services
./platform.sh up prod

# 6. Restore data
./platform.sh restore prod backups/latest.sql.gz

# 7. Apply migrations
./platform.sh migrate prod

# 8. Verify
./platform.sh health prod
```

## Maintenance Schedule

### Daily
- [x] Backup automatico (3 AM)
- [x] Verifica backup (4 AM)
- [x] Health check (ogni 5 min)

### Weekly
- [ ] Review logs per errori
- [ ] Check disk space
- [ ] Verify backup restore (ambiente test)

### Monthly
- [ ] Update Docker images
- [ ] Review security advisories
- [ ] Performance review
- [ ] Capacity planning

### Quarterly
- [ ] Disaster recovery drill
- [ ] Security audit
- [ ] Documentation review
- [ ] Team training

## Rollback Procedure

Se deployment fallisce:

```bash
# 1. Stop new version
./platform.sh down prod

# 2. Restore previous backup
./platform.sh restore prod backups/pre-deployment-backup.sql.gz

# 3. Revert code
git checkout <previous-version>

# 4. Start old version
./platform.sh up prod

# 5. Verify
./platform.sh health prod
```

## Support Contacts

Documenta:
- [ ] Team contacts (dev, ops, security)
- [ ] Vendor support (Supabase, n8n)
- [ ] Hosting provider support
- [ ] On-call schedule

## Compliance & Audit

Se necessario:
- [ ] GDPR compliance check
- [ ] Data retention policies
- [ ] Audit logging
- [ ] Access control review
- [ ] Security certifications

---

**IMPORTANTE**: Questo è un sistema self-hosted. Sei responsabile per:
- Sicurezza
- Availability
- Backup
- Updates
- Monitoring
- Incident response

Pianifica di conseguenza!
