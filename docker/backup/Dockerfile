# =============================================================================
# Backup Container
# =============================================================================
# Container dedicato per backup automatici e on-demand

FROM postgres:15-alpine

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    rclone \
    tzdata \
    dcron

# Set timezone
ENV TZ=Europe/Rome

# Create app directory
WORKDIR /app

# Copy scripts
COPY backup.sh /app/backup.sh
COPY restore.sh /app/restore.sh
COPY crontab /etc/crontabs/root

# Make scripts executable
RUN chmod +x /app/backup.sh /app/restore.sh

# Create backup directory
RUN mkdir -p /backups

# Entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["crond", "-f", "-l", "2"]
