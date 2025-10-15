#!/bin/bash
# Health check script for the application

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================"
echo "Application Health Check"
echo "================================================"

check_service() {
    local name=$1
    local url=$2
    
    echo -n "Checking $name... "
    if curl -f -s -o /dev/null "$url"; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

check_port() {
    local name=$1
    local port=$2
    
    echo -n "Checking $name (port $port)... "
    if sudo lsof -i :$port > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

# Check system services
echo ""
echo "System Services:"
echo "----------------"
check_port "MongoDB" 27017
check_port "Backend" 8001
check_port "Frontend" 3000
check_port "Nginx" 80

# Check HTTP endpoints
echo ""
echo "HTTP Endpoints:"
echo "----------------"
check_service "Backend API" "http://localhost:8001/api/"
check_service "Frontend" "http://localhost:3000"
check_service "Nginx Proxy" "http://localhost/"

# Check supervisor status
echo ""
echo "Supervisor Status:"
echo "----------------"
if command -v supervisorctl &> /dev/null; then
    supervisorctl status 2>/dev/null || echo -e "${YELLOW}Supervisor not configured${NC}"
else
    echo -e "${YELLOW}Supervisor not installed${NC}"
fi

# Check MongoDB connection
echo ""
echo "Database Connection:"
echo "----------------"
if mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ MongoDB connection OK${NC}"
else
    echo -e "${RED}✗ MongoDB connection FAILED${NC}"
fi

# Disk usage
echo ""
echo "Disk Usage:"
echo "----------------"
df -h / | tail -n 1

# Memory usage
echo ""
echo "Memory Usage:"
echo "----------------"
free -h | grep Mem

echo ""
echo "================================================"
