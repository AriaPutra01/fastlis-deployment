#!/bin/bash
set -e

# ============================================
# LIMS One-Click Installer
# ============================================

echo "🚀 LIMS Installation Started..."

# COLOR OUTPUT
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================
# STEP 1: INTERACTIVE SETUP
# ============================================
echo -e "${BLUE}=== Step 1: Basic Configuration ===${NC}"

read -p "Enter App Name [fastlis]: " APP_NAME < /dev/tty
APP_NAME=${APP_NAME:-fastlis}

read -p "Enter Installation Path [/opt/fastlis]: " INSTALL_PATH < /dev/tty
INSTALL_PATH=${INSTALL_PATH:-/opt/fastlis}

read -p "Enter GitHub Token (leave empty if repo is public): " GITHUB_TOKEN < /dev/tty

# LIMS uses Postgres + Redis
echo -e "${GREEN}Database selected: PostgreSQL & Redis${NC}"
read -p "PostgreSQL password: " -s DB_PASSWORD < /dev/tty
echo
read -p "Redis password: " -s REDIS_PASSWORD < /dev/tty
echo

echo -e "${BLUE}=== LIMS Integration (fastlis-sync) ===${NC}"
read -p "Bridge Mode (API/DB) [API]: " BRIDGE_MODE < /dev/tty
BRIDGE_MODE=${BRIDGE_MODE:-API}

read -p "Sync Port [8081]: " SYNC_PORT < /dev/tty
SYNC_PORT=${SYNC_PORT:-8081}

# STEP 2: SYSTEM CHECK
# ============================================
echo -e "${BLUE}=== Step 2: System Verification ===${NC}"

check_command() {
  if ! command -v $1 &> /dev/null; then
    echo -e "${YELLOW}⚠️  $1 not found. Installing...${NC}"
    return 1
  else
    echo -e "${GREEN}✓ $1 installed${NC}"
    return 0
  fi
}

install_docker() {
  echo -e "${YELLOW}Installing Docker...${NC}"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm -f get-docker.sh
  sudo usermod -aG docker $USER
  echo -e "${GREEN}✓ Docker installed (user relogin diperlukan)${NC}"
}

install_docker_compose() {
  echo -e "${YELLOW}Installing Docker Compose...${NC}"
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo -e "${GREEN}✓ Docker Compose installed${NC}"
}

check_command "curl" || { sudo apt-get update && sudo apt-get install -y curl; }
check_command "git" || { sudo apt-get install -y git; }
check_command "docker" || install_docker
check_command "docker-compose" || install_docker_compose

# ============================================
# STEP 3: SETUP DIRECTORY & CLONE REPO
# ============================================
echo -e "${BLUE}=== Step 3: Creating Installation Directory ===${NC}"

sudo mkdir -p $INSTALL_PATH
sudo chown $USER $INSTALL_PATH

cd $INSTALL_PATH

if [ ! -d ".git" ]; then
  echo -e "${YELLOW}Cloning repository...${NC}"
  
  if [ -z "$GITHUB_TOKEN" ]; then
    git clone https://github.com/AriaPutra01/fastlis-deployment.git .
  else
    git clone https://$GITHUB_TOKEN@github.com/AriaPutra01/fastlis-deployment.git .
  fi
  
  echo -e "${GREEN}✓ Repository cloned${NC}"
fi

# ============================================
# STEP 4: CREATE ENVIRONMENT FILE
# ============================================
echo -e "${BLUE}=== Step 4: Creating Configuration ===${NC}"

# Generate random JWT secret if not provided
JWT_SECRET=$(openssl rand -hex 32)
API_KEY=$(openssl rand -hex 16)

cat > .env << EOF
# Auto-generated configuration
APP_NAME=$APP_NAME
APP_ENV=production
PORT=8080
ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,http://frontend:5173

# Database configuration
BLUEPRINT_DB_HOST=psql_bp
BLUEPRINT_DB_PORT=5432
BLUEPRINT_DB_DATABASE=fastlis
BLUEPRINT_DB_USERNAME=postgres
BLUEPRINT_DB_PASSWORD=$DB_PASSWORD
BLUEPRINT_DB_SCHEMA=public
BLUEPRINT_DB_MIGRATION_PATH=file://internal/database/migrations

# Redis configuration
REDIS_HOST=redis_bp
REDIS_PORT=6379
REDIS_PASSWORD=$REDIS_PASSWORD

# Security
JWT_SECRET=$JWT_SECRET
JWT_ACCESS_EXPIRY=60
JWT_REFRESH_EXPIRY=7
LOG_LEVEL=4

# Integration & Messaging (fastlis-v2 Core)
RABBITMQ_USER=guest
RABBITMQ_PASS=guest
API_KEY=$API_KEY

# Sync Proxy (fastlis-sync)
BRIDGE_MODE=$BRIDGE_MODE
SYNC_PORT=$SYNC_PORT
EOF

echo -e "${GREEN}✓ Configuration saved to .env${NC}"

# ============================================
# STEP 5: FIRST DEPLOYMENT
# ============================================
echo -e "${BLUE}=== Step 5: First Deployment ===${NC}"

if [ ! -z "$GITHUB_TOKEN" ]; then
  echo -e "${YELLOW}Logging in to GitHub Container Registry (GHCR)...${NC}"
  echo $GITHUB_TOKEN | docker login ghcr.io -u AriaPutra01 --password-stdin
fi

docker compose pull || true
docker compose up -d

# Wait for app startup
echo "Waiting for application startup (30 seconds)..."
sleep 30

if docker compose ps | grep -q "Up\|running"; then
  echo -e "${GREEN}✓ Application running!${NC}"
else
  echo -e "${RED}⚠️  Check logs: docker compose logs${NC}"
fi

# ============================================
# STEP 6: POST-INSTALL
# ============================================
echo -e "${BLUE}=== Step 6: Post-Installation Setup ===${NC}"

echo -e "${GREEN}✓ Installation Complete!${NC}"
echo ""
echo "📋 Quick Links:"
echo "  Frontend: http://localhost:5173"
echo "  Backend API: http://localhost:8080"
echo "  Sync Proxy (Mode $BRIDGE_MODE): http://localhost:$SYNC_PORT"
echo "  Logs: docker compose logs -f"
echo "  Update now: lims-update"
echo "  View status: docker compose ps"
echo ""
echo "📚 Next Steps:"
echo "  1. Access dashboard and complete initial setup"
echo "  2. Configure database backups"
echo "  3. Test updates: lims-update"
