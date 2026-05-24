#!/bin/bash
# Setup ansible-pull untuk auto-deployment

INSTALL_PATH=$1
UPDATE_FREQ=$2

# Install Ansible
sudo apt-get update && sudo apt-get install -y ansible

# Create deployment runner script
sudo tee /usr/local/bin/lims-update > /dev/null << 'SCRIPT'
#!/bin/bash
cd $INSTALL_PATH
# Uncomment and configure below if using ansible playbook:
# ansible-pull -d . -U https://github.com/AriaPutra01/fastlis-deployment.git -i localhost, deploy/playbook.yml
# For simple docker compose update:
git pull
docker compose pull
docker compose up -d
SCRIPT

sudo chmod +x /usr/local/bin/lims-update

# Setup cron based on frequency
case $UPDATE_FREQ in
  realtime)
    CRON="*/5 * * * *"  # Every 5 minutes
    ;;
  daily)
    CRON="0 2 * * *"    # Every day at 2 AM
    ;;
  weekly)
    CRON="0 2 * * 0"    # Every Sunday at 2 AM
    ;;
esac

echo "$CRON root $INSTALL_PATH/scripts/run-update.sh >> /var/log/lims-update.log 2>&1" | sudo tee /etc/cron.d/lims-auto-update
echo "✓ Cron job scheduled"
