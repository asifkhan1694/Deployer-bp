#!/bin/bash
################################################################################
# QUICK UPDATE SCRIPT
# Fast git pull and restart - no questions asked
# 
# Usage: sudo bash quick_update.sh
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_DIR="/app"

echo -e "${CYAN}🚀 Quick Update Starting...${NC}"
echo ""

# Pull latest changes
echo -e "${CYAN}1/4 Pulling latest code...${NC}"
cd $APP_DIR
git pull

# Update backend dependencies
echo -e "${CYAN}2/4 Updating backend dependencies...${NC}"
cd $APP_DIR/backend
pip3 install -r requirements.txt -q

# Update frontend dependencies (if package.json changed)
echo -e "${CYAN}3/4 Checking frontend dependencies...${NC}"
cd $APP_DIR/frontend
if [ -f "yarn.lock" ]; then
    yarn install --silent 2>&1 | tail -1
else
    npm install --silent 2>&1 | tail -1
fi

# Restart all services
echo -e "${CYAN}4/4 Restarting services...${NC}"
supervisorctl restart all 2>&1 | grep -E "started|ERROR" || true

# Wait a moment
sleep 3

# Health check
echo ""
echo -e "${GREEN}✓ Update complete!${NC}"
echo ""

# Show status
echo "Service Status:"
supervisorctl status 2>&1 | head -10

echo ""
echo -e "${YELLOW}Tip: View logs with${NC}"
echo "  tail -f /var/log/supervisor/*.err.log"
echo ""
