#!/bin/bash
################################################################################
# FIXED DEPLOYMENT SCRIPT - Handles Node.js and Package Issues
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}          ${BOLD}🚀 FASTAPI + REACT AUTO INSTALLER 🚀${NC}                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                  ${YELLOW}(FIXED VERSION)${NC}                              ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: Run with sudo${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Running as root${NC}"
echo ""

# Quick config
echo -e "${BOLD}Configuration:${NC}"
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
echo "  Repo: $GIT_REPO"
echo "  Database: $([ "$MONGO_SELF_HOSTED" = true ] && echo "Self-hosted" || echo "Atlas")"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "Press Enter to start..."

LOG_FILE="/var/log/auto_deploy_fixed_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 1: System Update & Package Manager Fix"
echo "═══════════════════════════════════════════════════════════════"
echo ""

killall apt apt-get 2>/dev/null || true
rm -f /var/lib/dpkg/lock* 2>/dev/null || true
dpkg --configure -a

# Fix apt_pkg errors
echo "→ Fixing apt_pkg module..."
apt-get install --reinstall python3-apt -y 2>/dev/null || true

DEBIAN_FRONTEND=noninteractive apt-get update -y 2>&1 | grep -E "Get:|Fetched|Reading" | tail -10
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" 2>&1 | grep -E "upgraded|Setting up" | tail -10

echo -e "${GREEN}✓ System updated${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 2: Installing Essential Tools"
echo "═══════════════════════════════════════════════════════════════"
echo ""
DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential curl wget git \
    software-properties-common apt-transport-https ca-certificates gnupg supervisor nginx

echo -e "${GREEN}✓ Tools installed${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 3: Installing Python 3.11"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Fix add-apt-repository
export DEBIAN_FRONTEND=noninteractive
apt-get install -y software-properties-common python3-launchpadlib

add-apt-repository -y ppa:deadsnakes/ppa 2>&1 | tail -5
apt-get update -y 2>&1 | grep -v "Get:" | tail -5
apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

echo -e "${GREEN}✓ Python $(python3 --version) installed${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 4: Installing Node.js 20.x (FIXED METHOD)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Remove old Node.js first
echo "→ Removing old Node.js..."
apt-get remove -y nodejs npm 2>/dev/null || true
apt-get autoremove -y

# Install Node.js 20.x properly
echo "→ Adding Node.js 20.x repository..."
curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh
bash /tmp/nodesource_setup.sh

echo "→ Installing Node.js 20.x..."
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

echo "→ Verifying installation..."
node --version
npm --version

echo "→ Installing Yarn..."
npm install -g yarn
yarn --version

echo -e "${GREEN}✓ Node.js $(node --version) and Yarn $(yarn --version) installed${NC}"

if [ "$MONGO_SELF_HOSTED" = true ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "STEP 5: Installing MongoDB 7.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
        gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
        tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    
    apt-get update -y 2>&1 | grep -v "Get:" | tail -5
    DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org 2>&1 | grep -E "Unpacking|Setting up" | tail -10
    
    systemctl enable mongod
    systemctl start mongod
    sleep 3
    
    echo -e "${GREEN}✓ MongoDB installed and running${NC}"
else
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "STEP 5: Skipping MongoDB (using Atlas)"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${GREEN}✓ Using MongoDB Atlas${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 6: Cloning Application"
echo "═══════════════════════════════════════════════════════════════"
echo ""

mkdir -p /opt/app
cd /opt/app

if [ -d ".git" ]; then
    echo "→ App directory exists, pulling latest..."
    git fetch origin
    git reset --hard origin/$GIT_BRANCH
else
    echo "→ Cloning from $GIT_REPO..."
    git clone -b $GIT_BRANCH $GIT_REPO temp_clone
    mv temp_clone/* temp_clone/.[!.]* . 2>/dev/null || true
    rm -rf temp_clone
fi

COMMIT_ID=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo -e "${GREEN}✓ Application cloned (commit: $COMMIT_ID)${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 7: Setting Up Backend"
echo "═══════════════════════════════════════════════════════════════"
echo ""

cd /opt/app/backend

# Create venv
python3 -m venv /opt/app/venv
source /opt/app/venv/bin/activate

# Fix requirements.txt if it has emergentintegrations
if grep -q "emergentintegrations" requirements.txt 2>/dev/null; then
    echo "→ Fixing requirements.txt (removing emergentintegrations)..."
    grep -v "emergentintegrations" requirements.txt > requirements_fixed.txt
    mv requirements_fixed.txt requirements.txt
fi

echo "→ Installing Python packages..."
pip install --upgrade pip 2>&1 | tail -2
pip install -r requirements.txt 2>&1 | grep -E "Successfully installed|Requirement already" | tail -10

# Create .env
cat > .env <<EOF
MONGO_URL=$MONGO_URL
DB_NAME=${DB_NAME:-app_database}
CORS_ORIGINS=*
EOF

echo -e "${GREEN}✓ Backend configured${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 8: Setting Up Frontend"
echo "═══════════════════════════════════════════════════════════════"
echo ""

cd /opt/app/frontend

cat > .env <<EOF
REACT_APP_BACKEND_URL=http://$SERVER_IP
PORT=$FRONTEND_PORT
EOF

echo "→ Installing Node packages (3-5 minutes)..."
yarn install --frozen-lockfile 2>&1 | grep -E "success|warning|Done in"

echo -e "${GREEN}✓ Frontend configured${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 9: Configuring Services"
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

echo -e "${GREEN}✓ Services started${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "STEP 10: Configuring Nginx"
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

echo -e "${GREEN}✓ Nginx configured${NC}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Verifying Installation..."
echo "═══════════════════════════════════════════════════════════════"
echo ""

sleep 5

echo "→ Checking services..."
supervisorctl status

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "${BOLD}${GREEN}🎉 INSTALLATION COMPLETE! 🎉${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${BOLD}🌐 Application:${NC}  http://$SERVER_IP"
echo -e "  ${BOLD}📡 API Docs:${NC}     http://$SERVER_IP/api/docs"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Useful commands:"
echo "  sudo supervisorctl status          - Check services"
echo "  sudo supervisorctl restart all     - Restart services"
echo "  sudo tail -f /var/log/supervisor/backend.out.log"
echo "  sudo tail -f /var/log/supervisor/frontend.out.log"
echo ""
echo "Log file: $LOG_FILE"
echo ""
