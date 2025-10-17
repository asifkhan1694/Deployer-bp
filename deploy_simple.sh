#!/bin/bash
# SIMPLEST DOCKER DEPLOYMENT - ZERO FILES NEEDED LOCALLY

set -e

echo "======================================"
echo "SIMPLE DOCKER DEPLOYMENT"
echo "======================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Run with sudo"
    exit 1
fi

# Determine docker-compose command
if docker compose version &> /dev/null 2>&1; then
    DC="docker compose"
elif docker-compose --version &> /dev/null 2>&1; then
    DC="docker-compose"
else
    echo "ERROR: Docker Compose not found"
    echo "Install with: apt-get install docker-compose-plugin"
    exit 1
fi

echo "✓ Using: $DC"
echo ""

# Get config
echo "Configuration:"
read -p "GitHub repo URL: " GIT_REPO
read -p "Branch (default: main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}
read -p "Database choice (1=self-hosted, 2=atlas): " DB_CHOICE

if [ "$DB_CHOICE" = "2" ]; then
    read -p "MongoDB Atlas URL: " MONGO_URL
else
    MONGO_URL="mongodb://localhost:27017"
    read -p "Database name (default: app_database): " DB_NAME
    DB_NAME=${DB_NAME:-app_database}
fi

SERVER_IP=$(curl -s ifconfig.me || echo "localhost")
BACKEND_URL="http://$SERVER_IP:8001"

# Save config
cat > .env <<EOF
GIT_REPO=$GIT_REPO
GIT_BRANCH=$GIT_BRANCH
MONGO_URL=$MONGO_URL
DB_NAME=${DB_NAME:-app_database}
BACKEND_URL=$BACKEND_URL
CORS_ORIGINS=*
EOF

echo ""
echo "Configuration:"
cat .env
echo ""

read -p "Press Enter to build (takes 10 minutes)..."

echo ""
echo "Building container..."
echo "This will take 10 minutes the first time."
echo ""

$DC -f docker-compose.simple.yml build

echo ""
echo "Starting container..."
$DC -f docker-compose.simple.yml down 2>/dev/null || true
$DC -f docker-compose.simple.yml up -d

echo ""
echo "Waiting for startup (60 seconds)..."
sleep 60

echo ""
echo "======================================"
echo "STATUS"
echo "======================================"
$DC -f docker-compose.simple.yml ps

echo ""
echo "======================================"
echo "SUCCESS!"
echo "======================================"
echo ""
echo "Application: http://$SERVER_IP"
echo "API Docs:    http://$SERVER_IP/api/docs"
echo ""
echo "View logs:"
echo "  $DC -f docker-compose.simple.yml logs -f"
echo ""
echo "Restart:"
echo "  $DC -f docker-compose.simple.yml restart"
echo ""
echo "Update code:"
echo "  $DC -f docker-compose.simple.yml down"
echo "  $DC -f docker-compose.simple.yml build --no-cache"
echo "  $DC -f docker-compose.simple.yml up -d"
echo ""
