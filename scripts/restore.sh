#!/bin/bash
read -p "Enter backup file path: " BACKUP_FILE
if [ ! -f "$BACKUP_FILE" ]; then
    echo "File not found!"
    exit 1
fi
docker compose exec -T psql_bp psql -U postgres -d fastlis < $BACKUP_FILE
echo "✓ Database restored from $BACKUP_FILE"
