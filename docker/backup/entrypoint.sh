#!/usr/bin/env bash

# =============================================================================
# Backup Container Entrypoint
# =============================================================================

set -e

echo "=========================================="
echo "Backup Container Starting"
echo "Environment: ${ENVIRONMENT:-unknown}"
echo "=========================================="

# Configura crontab dinamicamente
BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-0 2 * * *}"

echo "Configuring cron schedule: $BACKUP_SCHEDULE"

# Crea crontab con variabili d'ambiente
cat > /etc/crontabs/root << EOF
# Backup schedule
${BACKUP_SCHEDULE} /app/backup.sh >> /var/log/backup.log 2>&1
EOF

echo "Crontab configured:"
cat /etc/crontabs/root

# Crea log file
touch /var/log/backup.log

echo "Starting cron daemon..."
echo "=========================================="

# Esegui comando passato (default: crond -f -l 2)
exec "$@"
