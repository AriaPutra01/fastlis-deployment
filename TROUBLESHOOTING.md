# Troubleshooting Guide

## App won't start
```bash
# View backend logs
docker compose logs -f app

# View frontend logs
docker compose logs -f frontend
```

## Database connection error
- Check the generated credentials in `.env`
- Verify database health:
```bash
docker compose ps
```

## Update failed
```bash
# View auto-update logs
cat /var/log/lims-update.log

# Run manual update
lims-update
```

## Reset everything
```bash
# ⚠️ WARNING: This will delete ALL data (database, redis)
docker compose down -v  

# Re-run installer
./install.sh            
./install.ps1            
```
