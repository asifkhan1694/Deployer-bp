#!/bin/bash
# Quick start guide - Interactive setup script

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================"
echo "FastAPI + React Quick Start Setup"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}This script must be run as root${NC}"
    echo "Please run: sudo ./quick_start.sh"
    exit 1
fi

# Step 1: Check if already installed
echo -e "${BLUE}[Step 1/5]${NC} Checking existing installation..."
if command -v node &> /dev/null && command -v python3.11 &> /dev/null && command -v mongod &> /dev/null; then
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
    read -p "Do you want to skip installation? (y/n): " skip_install
    if [[ $skip_install == "y" || $skip_install == "Y" ]]; then
        echo "Skipping installation..."
    else
        echo "Running installation..."
        ./install.sh
    fi
else
    echo -e "${YELLOW}Dependencies not found. Installing...${NC}"
    ./install.sh
fi

# Step 2: Get git repository
echo ""
echo -e "${BLUE}[Step 2/5]${NC} Git Repository Configuration"
read -p "Enter your Git repository URL: " git_repo
read -p "Enter branch name (default: main): " git_branch
git_branch=${git_branch:-main}

# Create .env file
cat > .env <<EOF
GIT_REPO=$git_repo
GIT_BRANCH=$git_branch
APP_DIR=/opt/app
VENV_PATH=/opt/app/venv
APP_USER=appuser
EOF

echo -e "${GREEN}✓ Configuration saved to .env${NC}"

# Step 3: Clone repository
echo ""
echo -e "${BLUE}[Step 3/5]${NC} Cloning repository..."
if [ -d "/opt/app" ]; then
    read -p "/opt/app already exists. Remove and re-clone? (y/n): " remove_existing
    if [[ $remove_existing == "y" || $remove_existing == "Y" ]]; then
        rm -rf /opt/app
        git clone -b $git_branch $git_repo /opt/app
    fi
else
    git clone -b $git_branch $git_repo /opt/app
fi

# Copy deployment scripts to /opt/app
cp deploy.sh setup_supervisor.sh health_check.sh logs.sh .env /opt/app/
chmod +x /opt/app/*.sh

echo -e "${GREEN}✓ Repository cloned to /opt/app${NC}"

# Step 4: Configure environment variables
echo ""
echo -e "${BLUE}[Step 4/5]${NC} Environment Configuration"

# Backend .env
if [ ! -f "/opt/app/backend/.env" ]; then
    echo "Creating backend .env..."
    read -p "Enter MongoDB database name (default: app_database): " db_name
    db_name=${db_name:-app_database}
    
    cat > /opt/app/backend/.env <<EOF
MONGO_URL=mongodb://localhost:27017
DB_NAME=$db_name
CORS_ORIGINS=*
EOF
    echo -e "${GREEN}✓ Backend .env created${NC}"
else
    echo -e "${YELLOW}Backend .env already exists${NC}"
fi

# Frontend .env
if [ ! -f "/opt/app/frontend/.env" ]; then
    echo "Creating frontend .env..."
    read -p "Enter backend URL (default: http://localhost:8001): " backend_url
    backend_url=${backend_url:-http://localhost:8001}
    
    cat > /opt/app/frontend/.env <<EOF
REACT_APP_BACKEND_URL=$backend_url
PORT=3000
EOF
    echo -e "${GREEN}✓ Frontend .env created${NC}"
else
    echo -e "${YELLOW}Frontend .env already exists${NC}"
fi

# Step 5: Deploy
echo ""
echo -e "${BLUE}[Step 5/5]${NC} Deploying application..."
cd /opt/app

# Setup supervisor
./setup_supervisor.sh

# Deploy
source .env
./deploy.sh

# Final status
echo ""
echo "================================================"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "================================================"
echo ""
echo "Your application is now running:"
echo "  - Frontend: http://$(curl -s ifconfig.me)"
echo "  - Backend API: http://$(curl -s ifconfig.me)/api/"
echo "  - Health Check: http://$(curl -s ifconfig.me)/health"
echo ""
echo "Useful commands:"
echo "  cd /opt/app && ./health_check.sh    # Check application health"
echo "  cd /opt/app && ./logs.sh backend -f # View backend logs"
echo "  cd /opt/app && ./deploy.sh          # Redeploy from git"
echo "  supervisorctl status                # Check service status"
echo ""
echo "To redeploy later:"
echo "  cd /opt/app && sudo -E ./deploy.sh"
echo ""
