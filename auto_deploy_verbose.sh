#!/bin/bash
################################################################################
# ULTRA-VERBOSE ONE-COMMAND DEPLOYMENT SCRIPT
# Shows EVERYTHING that's happening - no more freezing!
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}          ${BOLD}🚀 FASTAPI + REACT AUTO INSTALLER 🚀${NC}                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}            ${WHITE}One-Command Production Deployment${NC}                   ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                  ${YELLOW}(VERBOSE MODE)${NC}                              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo ""
echo -e "${YELLOW}This version shows ALL output - nothing is hidden!${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This script must be run with sudo${NC}"
    echo "Run: sudo bash $0"
    exit 1
fi

echo -e "${GREEN}✓ Running as root${NC}"
echo ""

# Collect minimal info
echo -e "${BOLD}Quick Configuration:${NC}"
echo ""
read -p "GitHub repository URL: " GIT_REPO
read -p "Branch (default: main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}
read -p "Database: 1=Self-hosted, 2=Atlas (default: 1): " MONGO_CHOICE
MONGO_CHOICE=${MONGO_CHOICE:-1}

if [ "$MONGO_CHOICE" = "2" ]; then
    read -p "MongoDB Atlas URL: " MONGO_URL
    MONGO_SELF_HOSTED=false
else
    MONGO_SELF_HOSTED=true
    read -p "Database name (default: app_database): " DB_NAME
    DB_NAME=${DB_NAME:-app_database}
    MONGO_URL="mongodb://localhost:27017/$DB_NAME"
fi

SERVER_IP=$(curl -s ifconfig.me || echo "localhost")
FRONTEND_PORT=3000
BACKEND_PORT=8001

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Configuration Summary:${NC}"
echo "  Repo: $GIT_REPO"
echo "  Branch: $GIT_BRANCH"
echo "  Database: $([ "$MONGO_SELF_HOSTED" = true ] && echo "Self-hosted ($DB_NAME)" || echo "Atlas")"
echo "  Server IP: $SERVER_IP"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
read -p "Press Enter to start installation..."

LOG_FILE="/var/log/auto_deploy_verbose_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 1/10: Fixing Package Manager & Updating System"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "→ Killing any stuck apt processes..."
killall apt apt-get 2>/dev/null || echo "  (none found)"

echo "→ Removing lock files..."
rm -f /var/lib/apt/lists/lock 2>/dev/null || true
rm -f /var/cache/apt/archives/lock 2>/dev/null || true
rm -f /var/lib/dpkg/lock* 2>/dev/null || true
echo "  ✓ Locks cleared"

echo "→ Fixing any broken packages..."
dpkg --configure -a
echo "  ✓ Fixed"

echo ""
echo "→ Updating package lists (you'll see downloads)..."
echo ""
DEBIAN_FRONTEND=noninteractive apt-get update -y

echo ""
echo "→ Upgrading system packages..."
echo ""
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

echo ""
echo -e "${GREEN}✓ System updated successfully!${NC}"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 2/10: Installing Essential Tools"
echo "═══════════════════════════════════════════════════════════════"
echo ""
DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential curl wget git \
    software-properties-common apt-transport-https ca-certificates \
    gnupg lsb-release supervisor nginx

echo ""
echo -e "${GREEN}✓ Essential tools installed!${NC}"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 3/10: Installing Python 3.11"
echo "═══════════════════════════════════════════════════════════════"
echo ""
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

echo ""
echo -e "${GREEN}✓ Python $(python3 --version) installed!${NC}"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 4/10: Installing Node.js 20.x and Yarn"
echo "═══════════════════════════════════════════════════════════════"
echo ""
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
npm install -g yarn

echo ""
echo -e "${GREEN}✓ Node.js $(node --version) and Yarn $(yarn --version) installed!${NC}"
echo ""

if [ "$MONGO_SELF_HOSTED" = true ]; then
    echo "═══════════════════════════════════════════════════════════════"
    echo "STEP 5/10: Installing MongoDB 7.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
        gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
        tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org
    systemctl enable mongod
    systemctl start mongod
    echo ""
    echo -e "${GREEN}✓ MongoDB installed and running!${NC}"
    echo ""
else
    echo "═══════════════════════════════════════════════════════════════"
    echo "STEP 5/10: Skipping MongoDB (using Atlas)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo -e "${GREEN}✓ Using MongoDB Atlas${NC}"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 6/10: Cloning Your Application"
echo "═══════════════════════════════════════════════════════════════"
echo ""
mkdir -p /opt/app
cd /opt/app
git clone -b $GIT_BRANCH $GIT_REPO temp_clone
mv temp_clone/* temp_clone/.[!.]* . 2>/dev/null || true
rm -rf temp_clone
COMMIT_ID=$(git rev-parse --short HEAD)

echo ""
echo -e "${GREEN}✓ Application cloned (commit: $COMMIT_ID)!${NC}"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 7/10: Setting Up Backend"
echo "═══════════════════════════════════════════════════════════════"
echo ""
cd /opt/app/backend
python3 -m venv /opt/app/venv
source /opt/app/venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

cat > .env <<EOF
MONGO_URL=$MONGO_URL
DB_NAME=${DB_NAME:-app_database}
CORS_ORIGINS=*
EOF

echo ""
echo -e "${GREEN}✓ Backend configured!${NC}"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 8/10: Setting Up Frontend"
echo "═══════════════════════════════════════════════════════════════"
echo ""
cd /opt/app/frontend

cat > .env <<EOF
REACT_APP_BACKEND_URL=http://$SERVER_IP
PORT=$FRONTEND_PORT
EOF

echo "Installing Node packages (this takes 3-5 minutes)..."
yarn install --frozen-lockfile

echo ""
echo -e "${GREEN}✓ Frontend configured!${NC}"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 9/10: Configuring Services"
echo "═══════════════════════════════════════════════════════════════"
echo ""

cat > /etc/supervisor/conf.d/app.conf <<EOF
[program:backend]
command=/opt/app/venv/bin/uvicorn server:app --host 0.0.0.0 --port $BACKEND_PORT --workers 2
directory=/opt/app/backend
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/backend.err.log
stdout_logfile=/var/log/supervisor/backend.out.log

[program:frontend]
command=yarn start
directory=/opt/app/frontend
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/frontend.err.log
stdout_logfile=/var/log/supervisor/frontend.out.log
environment=HOST="0.0.0.0",PORT="$FRONTEND_PORT"
EOF

supervisorctl reread
supervisorctl update
sleep 2
supervisorctl start all

echo ""
echo -e "${GREEN}✓ Services started!${NC}"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "STEP 10/10: Configuring Nginx"
echo "═══════════════════════════════════════════════════════════════"
echo ""

cat > /etc/nginx/sites-available/app <<EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:$FRONTEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}
EOF

ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

echo ""
echo -e "${GREEN}✓ Nginx configured!${NC}"
echo ""

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BOLD}${GREEN}🎉 SUCCESS! 🎉${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${BOLD}🌐 Your Application:${NC}  http://$SERVER_IP"
echo -e "  ${BOLD}📡 API Documentation:${NC} http://$SERVER_IP/api/docs"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Log file saved to: $LOG_FILE"
echo ""
