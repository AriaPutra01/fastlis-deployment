#!/bin/bash
BACKUP_DIR="/opt/fastlis-backups"
mkdir -p $BACKUP_DIR

docker compose exec -T psql_bp pg_dump -U postgres fastlis > $BACKUP_DIR/db-$(date +%Y%m%d-%H%M%S).sql
echo "✓ Database backup created in $BACKUP_DIR"
