#!/bin/bash
################################################################################
# SIMPLE UPDATE SCRIPT FOR EMERGENT DEPLOYMENTS
# Works with the current deployment in /app
# 
# Usage: sudo bash simple_update.sh
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_DIR="/app"

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🔄 Emergent Deployment Update 🔄   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}✗ This script must be run with sudo${NC}"
    exit 1
fi

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}✗ Application directory not found: $APP_DIR${NC}"
    exit 1
fi

echo -e "${CYAN}📂 Current deployment: $APP_DIR${NC}"
echo ""

# Show what's running
echo -e "${CYAN}📊 Current services:${NC}"
supervisorctl status 2>/dev/null | grep -E "(backend|frontend)" || echo "  No services found"
echo ""

# Update backend dependencies
if [ -f "$APP_DIR/backend/requirements.txt" ]; then
    echo -e "${CYAN}1/3 Updating backend dependencies...${NC}"
    cd $APP_DIR/backend
    pip3 install -r requirements.txt -q --upgrade 2>&1 | tail -3
    echo -e "${GREEN}✓ Backend dependencies updated${NC}"
    echo ""
fi

# Update frontend dependencies
if [ -f "$APP_DIR/frontend/package.json" ]; then
    echo -e "${CYAN}2/3 Updating frontend dependencies...${NC}"
    cd $APP_DIR/frontend
    
    if [ -f "yarn.lock" ]; then
        yarn install --silent 2>&1 | tail -2
    elif [ -f "package-lock.json" ]; then
        npm install --silent 2>&1 | tail -2
    fi
    echo -e "${GREEN}✓ Frontend dependencies updated${NC}"
    echo ""
fi

# Restart services
echo -e "${CYAN}3/3 Restarting services...${NC}"
supervisorctl restart backend frontend 2>&1 | grep -E "(started|ERROR)" || true

echo ""
echo -e "${GREEN}✓ Update complete!${NC}"
echo ""

# Wait for services to start
sleep 3

# Show status
echo -e "${CYAN}Service Status:${NC}"
supervisorctl status 2>/dev/null | grep -E "(backend|frontend|mongodb)"

echo ""
echo -e "${YELLOW}💡 Tip: View logs with:${NC}"
echo "   tail -f /var/log/supervisor/backend.err.log"
echo "   tail -f /var/log/supervisor/frontend.err.log"
echo ""
