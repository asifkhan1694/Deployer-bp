#!/bin/bash
# SIMPLEST DOCKER DEPLOYMENT - Just works!

set -e

echo "======================================"
echo "DOCKER DEPLOYMENT - SIMPLE VERSION"
echo "======================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Run with sudo"
    exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
fi

echo "✓ Docker installed"
docker --version

# Check Docker Compose
DOCKER_COMPOSE=""
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
    echo "✓ Using docker compose (plugin)"
elif docker-compose --version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
    echo "✓ Using docker-compose (standalone)"
else
    echo "Installing Docker Compose..."
    
    # Try plugin first
    apt-get install --reinstall python3-apt -y 2>/dev/null || true
    apt-get update 2>&1 | grep -v "Traceback" || true
    apt-get install -y docker-compose-plugin 2>&1 | tail -5 || true
    
    # Check again
    if docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    else
        # Install standalone
        echo "Installing standalone docker-compose..."
        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        DOCKER_COMPOSE="docker-compose"
    fi
fi

echo "✓ Docker Compose ready"
$DOCKER_COMPOSE version || $DOCKER_COMPOSE --version

echo ""
echo "======================================"
echo "Configuration"
echo "======================================"

read -p "GitHub repo URL: " GIT_REPO
read -p "Branch (default: main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}
read -p "Database (1=self, 2=atlas): " MONGO_CHOICE

if [ "$MONGO_CHOICE" = "2" ]; then
    read -p "Atlas URL: " MONGO_URL
else
    MONGO_URL="mongodb://localhost:27017"
    DB_NAME="app_database"
fi

SERVER_IP=$(curl -s ifconfig.me || echo "localhost")

# Create .env
cat > .env <<EOF
GIT_REPO=$GIT_REPO
GIT_BRANCH=$GIT_BRANCH
MONGO_URL=$MONGO_URL
DB_NAME=${DB_NAME:-app_database}
BACKEND_URL=http://$SERVER_IP:8001
CORS_ORIGINS=*
EOF

echo ""
echo "Configuration saved:"
cat .env

echo ""
read -p "Press Enter to build container (takes 10 minutes first time)..."

echo ""
echo "======================================"
echo "Building Container"
echo "======================================"
echo ""

$DOCKER_COMPOSE -f docker-compose.production.yml build

echo ""
echo "======================================"
echo "Starting Container"
echo "======================================"
echo ""

$DOCKER_COMPOSE -f docker-compose.production.yml down 2>/dev/null || true
$DOCKER_COMPOSE -f docker-compose.production.yml up -d

echo ""
echo "Waiting for startup (30 seconds)..."
sleep 30

echo ""
echo "======================================"
echo "Status"
echo "======================================"
echo ""

$DOCKER_COMPOSE -f docker-compose.production.yml ps

echo ""
echo "======================================"
echo "SUCCESS!"
echo "======================================"
echo ""
echo "Application: http://$SERVER_IP"
echo "API Docs:    http://$SERVER_IP/api/docs"
echo ""
echo "View logs:"
echo "  $DOCKER_COMPOSE -f docker-compose.production.yml logs -f"
echo ""
echo "Restart:"
echo "  $DOCKER_COMPOSE -f docker-compose.production.yml restart"
echo ""
echo "Stop:"
echo "  $DOCKER_COMPOSE -f docker-compose.production.yml down"
echo ""
