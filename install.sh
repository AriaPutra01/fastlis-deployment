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

read -p "Enter App Name [fastlis]: " APP_NAME
APP_NAME=${APP_NAME:-fastlis}

read -p "Enter Installation Path [/opt/fastlis]: " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-/opt/fastlis}

read -p "Enter GitHub Token (leave empty if repo is public): " GITHUB_TOKEN

read -p "Update frequency (realtime/daily/weekly) [daily]: " UPDATE_FREQ
UPDATE_FREQ=${UPDATE_FREQ:-daily}

# LIMS uses Postgres + Redis
echo -e "${GREEN}Database selected: PostgreSQL & Redis${NC}"
read -p "PostgreSQL password: " -s DB_PASSWORD
echo
read -p "Redis password: " -s REDIS_PASSWORD
echo

# ============================================
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
sudo chown $USER:$USER $INSTALL_PATH

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
JWT_ACCESS_EXPIRY=15
JWT_REFRESH_EXPIRY=7
LOG_LEVEL=4
EOF

echo -e "${GREEN}✓ Configuration saved to .env${NC}"

# ============================================
# STEP 5: SETUP AUTO-UPDATES
# ============================================
echo -e "${BLUE}=== Step 5: Configuring Auto-Updates ===${NC}"

if [ -f "scripts/ansible-pull-setup.sh" ]; then
  sudo cp -f scripts/ansible-pull-setup.sh /usr/local/bin/lims-deploy-setup
  sudo chmod +x /usr/local/bin/lims-deploy-setup
  sudo /usr/local/bin/lims-deploy-setup "$INSTALL_PATH" "$UPDATE_FREQ"
  echo -e "${GREEN}✓ Auto-update configured${NC}"
else
  echo -e "${YELLOW}⚠️ Auto-update script not found, skipping...${NC}"
fi

# ============================================
# STEP 6: FIRST DEPLOYMENT
# ============================================
echo -e "${BLUE}=== Step 6: First Deployment ===${NC}"

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
# STEP 7: POST-INSTALL
# ============================================
echo -e "${BLUE}=== Step 7: Post-Installation Setup ===${NC}"

echo -e "${GREEN}✓ Installation Complete!${NC}"
echo ""
echo "📋 Quick Links:"
echo "  Frontend: http://localhost:5173"
echo "  Backend API: http://localhost:8080"
echo "  Logs: docker compose logs -f"
echo "  Update now: lims-update"
echo "  View status: docker compose ps"
echo ""
echo "📚 Next Steps:"
echo "  1. Access dashboard and complete initial setup"
echo "  2. Configure database backups"
echo "  3. Test updates: lims-update"
