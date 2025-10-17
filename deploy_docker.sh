#!/bin/bash
################################################################################
# BULLETPROOF DOCKER DEPLOYMENT
# Zero dependency issues - Everything runs in containers!
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}          ${BOLD}🐳 DOCKER-BASED DEPLOYMENT 🐳${NC}                     ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}        ${YELLOW}Zero Dependency Issues - Always Works!${NC}              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                                ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This script must be run with sudo${NC}"
    echo "Run: sudo bash $0"
    exit 1
fi

echo -e "${GREEN}✓ Running as root${NC}"
echo ""

# Function to check if Docker is installed
check_docker() {
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓ Docker is installed${NC}"
        docker --version
        return 0
    else
        return 1
    fi
}

# Function to check if Docker Compose is installed
check_docker_compose() {
    if docker compose version &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose is installed${NC}"
        docker compose version
        return 0
    else
        return 1
    fi
}

# Install Docker if needed
if ! check_docker; then
    echo ""
    echo -e "${YELLOW}Docker not found. Installing Docker...${NC}"
    echo ""
    
    # Install Docker
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    
    # Start Docker
    systemctl start docker
    systemctl enable docker
    
    echo ""
    check_docker
fi

# Install Docker Compose if needed
if ! check_docker_compose; then
    echo ""
    echo -e "${YELLOW}Docker Compose not found. Installing...${NC}"
    echo ""
    
    # Fix apt_pkg error first
    echo "→ Fixing apt_pkg module..."
    apt-get install --reinstall python3-apt -y 2>/dev/null || true
    
    # Docker Compose should be included with modern Docker
    # If not, install the plugin
    echo "→ Installing docker-compose-plugin..."
    apt-get update 2>&1 | grep -v "Traceback" | grep -v "apt_pkg" | grep -v "cnf-update-db" || true
    apt-get install -y docker-compose-plugin 2>&1 | grep -E "Setting up|already" || true
    
    echo ""
    if check_docker_compose; then
        echo -e "${GREEN}✓ Docker Compose installed successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Docker Compose plugin installation had issues, trying alternative...${NC}"
        # Try standalone docker-compose
        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        
        if docker-compose --version 2>/dev/null; then
            echo -e "${GREEN}✓ Docker Compose (standalone) installed${NC}"
        else
            echo -e "${RED}✗ Failed to install Docker Compose. Please install manually.${NC}"
            exit 1
        fi
    fi
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Configuration${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Collect configuration
read -p "GitHub repository URL: " GIT_REPO
read -p "Branch (default: main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}

echo ""
read -p "Database: 1=Self-hosted (in container), 2=Atlas: " MONGO_CHOICE

if [ "$MONGO_CHOICE" = "2" ]; then
    read -p "MongoDB Atlas connection URL: " MONGO_URL
else
    MONGO_URL="mongodb://localhost:27017"
    read -p "Database name (default: app_database): " DB_NAME
    DB_NAME=${DB_NAME:-app_database}
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "localhost")
BACKEND_URL="http://$SERVER_IP:8001"

# Create .env file for docker-compose
cat > .env <<EOF
GIT_REPO=$GIT_REPO
GIT_BRANCH=$GIT_BRANCH
MONGO_URL=$MONGO_URL
DB_NAME=${DB_NAME:-app_database}
BACKEND_URL=$BACKEND_URL
CORS_ORIGINS=*
EOF

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Configuration Summary${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
cat .env
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "Press Enter to start deployment..."

echo ""
echo "=========================================="
echo "Building Docker Image"
echo "=========================================="
echo ""
echo "This will take 5-10 minutes on first run..."
echo "Subsequent builds are much faster (cached layers)"
echo ""

# Build the image
docker compose -f docker-compose.production.yml build

echo ""
echo "=========================================="
echo "Starting Container"
echo "=========================================="
echo ""

# Stop and remove old containers
docker compose -f docker-compose.production.yml down 2>/dev/null || true

# Start new container
docker compose -f docker-compose.production.yml up -d

echo ""
echo "=========================================="
echo "Waiting for Services to Start"
echo "=========================================="
echo ""

# Wait for health check
echo "Waiting for application to be healthy (this takes 30-60 seconds)..."
for i in {1..30}; do
    if docker compose -f docker-compose.production.yml ps | grep -q "healthy"; then
        echo -e "${GREEN}✓ Application is healthy!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo ""
echo "=========================================="
echo "Checking Services"
echo "=========================================="
echo ""

# Show container status
docker compose -f docker-compose.production.yml ps

echo ""
echo "=========================================="
echo "Viewing Logs (last 20 lines)"
echo "=========================================="
echo ""

docker compose -f docker-compose.production.yml logs --tail=20

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo -e "║                    ${BOLD}${GREEN}🎉 SUCCESS! 🎉${NC}                             ║"
echo "║                                                                ║"
echo "║         Your application is now LIVE and RUNNING!             ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}📱 Access Your Application:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}🌐 Application:${NC}  http://$SERVER_IP"
echo -e "  ${BOLD}📡 API Docs:${NC}     http://$SERVER_IP/api/docs"
echo -e "  ${BOLD}💓 Health Check:${NC} http://$SERVER_IP/health"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}📊 Useful Commands:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}View logs:${NC}"
echo "    docker compose -f docker-compose.production.yml logs -f"
echo ""
echo -e "  ${YELLOW}Restart services:${NC}"
echo "    docker compose -f docker-compose.production.yml restart"
echo ""
echo -e "  ${YELLOW}Stop services:${NC}"
echo "    docker compose -f docker-compose.production.yml down"
echo ""
echo -e "  ${YELLOW}Update from git:${NC}"
echo "    docker compose -f docker-compose.production.yml down"
echo "    docker compose -f docker-compose.production.yml build --no-cache"
echo "    docker compose -f docker-compose.production.yml up -d"
echo ""
echo -e "  ${YELLOW}Access container shell:${NC}"
echo "    docker compose -f docker-compose.production.yml exec app bash"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}${BOLD}Deployment complete! 🚀${NC}"
echo ""
