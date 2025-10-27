#!/bin/bash
################################################################################
# DOCKER APPLICATION UPDATE SCRIPT
# Updates Docker-deployed applications by rebuilding containers
# 
# Usage: sudo bash update_docker_application.sh
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║      🐳 DOCKER APPLICATION UPDATE TOOL 🐳                     ║"
    echo "║                                                                ║"
    echo "║       Update Docker-Deployed Applications from Git             ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

ask_yes_no() {
    local question=$1
    local default=$2
    
    echo ""
    echo -e "${YELLOW}❓ ${BOLD}$question${NC}"
    echo -e "${CYAN}   (Y/N, Default: $default)${NC}"
    read -p "   Your answer: " answer
    answer=${answer:-$default}
    
    case $answer in
        [Yy]* ) return 0;;
        [Nn]* ) return 1;;
        * ) 
            if [ "$default" = "Y" ]; then
                return 0
            else
                return 1
            fi
            ;;
    esac
}

################################################################################
# MAIN SCRIPT
################################################################################

print_banner

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "This script must be run with sudo"
    echo ""
    echo "Please run: sudo bash $0"
    exit 1
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker not found"
    echo ""
    echo "This script is for Docker-based deployments."
    echo "Install Docker first: https://docs.docker.com/engine/install/"
    exit 1
fi

# Determine docker-compose command
if docker compose version &> /dev/null 2>&1; then
    DC="docker compose"
elif docker-compose --version &> /dev/null 2>&1; then
    DC="docker-compose"
else
    print_error "Docker Compose not found"
    echo ""
    echo "Install with: apt-get install docker-compose-plugin"
    exit 1
fi

print_success "Using: $DC"

# Scan for docker-compose files
echo ""
print_info "Scanning for Docker deployments..."
echo ""

compose_dirs=()
declare -A seen_dirs

# Check common locations for docker-compose files
for location in . /opt/* /var/www/* /home/*/* /srv/*; do
    if [ -d "$location" ]; then
        # Check if any compose file exists
        has_compose=false
        for compose_file in docker-compose.yml docker-compose.simple.yml docker-compose.production.yml; do
            if [ -f "$location/$compose_file" ]; then
                has_compose=true
                break
            fi
        done
        
        if [ "$has_compose" = true ]; then
            # Get absolute path to avoid duplicates
            abs_path=$(cd "$location" && pwd)
            
            # Skip if we've already seen this directory
            if [ -z "${seen_dirs[$abs_path]}" ]; then
                seen_dirs[$abs_path]=1
                compose_dirs+=("$abs_path")
            fi
        fi
    fi
done

if [ ${#compose_files[@]} -eq 0 ]; then
    print_error "No docker-compose files found"
    echo ""
    echo "This script looks for:"
    echo "  • docker-compose.yml"
    echo "  • docker-compose.simple.yml"
    echo "  • docker-compose.production.yml"
    echo ""
    echo "In locations:"
    echo "  • Current directory"
    echo "  • /opt/*"
    echo "  • /var/www/*"
    echo "  • /home/*/*"
    echo "  • /srv/*"
    echo ""
    
    # Check if current directory has compose file
    if [ -f "docker-compose.yml" ] || [ -f "docker-compose.simple.yml" ]; then
        print_info "Found docker-compose file in current directory!"
        echo ""
        if ask_yes_no "Update application in current directory?" "Y"; then
            SELECTED_DIR=$(pwd)
            if [ -f "docker-compose.simple.yml" ]; then
                COMPOSE_FILE="docker-compose.simple.yml"
            else
                COMPOSE_FILE="docker-compose.yml"
            fi
        else
            exit 0
        fi
    else
        exit 1
    fi
else
    # Display found deployments
    echo -e "${BOLD}${GREEN}Found ${#compose_files[@]} Docker deployment(s):${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    counter=1
    for i in "${!compose_files[@]}"; do
        dir="${compose_dirs[$i]}"
        file="${compose_files[$i]}"
        
        # Check if containers are running
        cd "$dir"
        if $DC -f "$file" ps 2>/dev/null | grep -q "Up"; then
            status="🟢 Running"
        else
            status="⚫ Stopped"
        fi
        
        # Get container names
        containers=$($DC -f "$file" ps --format '{{.Service}}' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
        
        echo -e "${WHITE}[$counter]${NC} ${BOLD}$dir${NC}"
        echo -e "    ${CYAN}Compose File:${NC} $file"
        echo -e "    ${CYAN}Status:${NC} $status"
        if [ -n "$containers" ]; then
            echo -e "    ${CYAN}Services:${NC} $containers"
        fi
        echo ""
        
        ((counter++))
    done
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Select deployment
    if [ ${#compose_files[@]} -eq 1 ]; then
        SELECTION=1
        print_info "Only one deployment found, selecting automatically..."
    else
        read -p "Select deployment to update (1-${#compose_files[@]}) or 0 to exit: " SELECTION
        
        if [ "$SELECTION" -eq 0 ]; then
            echo "Update cancelled"
            exit 0
        fi
        
        if [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#compose_files[@]} ]; then
            print_error "Invalid selection"
            exit 1
        fi
    fi
    
    SELECTED_DIR="${compose_dirs[$((SELECTION-1))]}"
    COMPOSE_FILE="${compose_files[$((SELECTION-1))]}"
fi

echo ""
echo -e "${BOLD}Selected Deployment:${NC}"
echo -e "  📂 ${GREEN}$SELECTED_DIR${NC}"
echo -e "  📄 ${GREEN}$COMPOSE_FILE${NC}"
echo ""

cd "$SELECTED_DIR"

# Show current status
echo -e "${CYAN}Current Status:${NC}"
$DC -f "$COMPOSE_FILE" ps 2>/dev/null || echo "  No containers running"
echo ""

# Confirm update
if ! ask_yes_no "Proceed with update? (Will rebuild and restart)" "Y"; then
    echo "Update cancelled"
    exit 0
fi

################################################################################
# UPDATE PROCESS
################################################################################

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Starting Docker Update${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Step 1: Create backup of .env if exists
if [ -f ".env" ]; then
    echo ""
    print_info "Step 1/4: Backing up configuration..."
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp .env ".env.backup_$TIMESTAMP"
    print_success "Configuration backed up: .env.backup_$TIMESTAMP"
else
    echo ""
    print_warning "Step 1/4: No .env file found (skipping backup)"
fi

# Step 2: Stop containers
echo ""
print_info "Step 2/4: Stopping containers..."
$DC -f "$COMPOSE_FILE" down 2>&1 | tail -5
print_success "Containers stopped"

# Step 3: Rebuild with latest code
echo ""
print_info "Step 3/4: Rebuilding with latest code from git..."
echo ""
echo -e "${YELLOW}This will pull latest code from git and rebuild (may take 5-10 minutes)${NC}"
echo ""

# Build without cache to ensure fresh pull from git
$DC -f "$COMPOSE_FILE" build --no-cache 2>&1 | tail -20

print_success "Rebuild complete"

# Step 4: Start containers
echo ""
print_info "Step 4/4: Starting containers..."
$DC -f "$COMPOSE_FILE" up -d 2>&1 | tail -5
print_success "Containers started"

# Wait for startup
echo ""
print_info "Waiting for services to start (30 seconds)..."
sleep 30

################################################################################
# COMPLETION & HEALTH CHECK
################################################################################

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✓ Update Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}Current Status:${NC}"
$DC -f "$COMPOSE_FILE" ps
echo ""

# Show access URLs
if [ -f ".env" ]; then
    source .env
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
    echo -e "${CYAN}Access Your Application:${NC}"
    echo -e "  🌐 Application: http://$SERVER_IP"
    echo -e "  📡 API Docs:    http://$SERVER_IP:8001/docs"
    echo ""
fi

echo -e "${CYAN}📊 Useful commands:${NC}"
echo ""
echo -e "  ${WHITE}# View logs${NC}"
echo -e "  $DC -f $COMPOSE_FILE logs -f"
echo ""
echo -e "  ${WHITE}# Restart services${NC}"
echo -e "  $DC -f $COMPOSE_FILE restart"
echo ""
echo -e "  ${WHITE}# Stop services${NC}"
echo -e "  $DC -f $COMPOSE_FILE down"
echo ""
echo -e "  ${WHITE}# Check status${NC}"
echo -e "  $DC -f $COMPOSE_FILE ps"
echo ""
echo -e "  ${WHITE}# Update again${NC}"
echo -e "  sudo bash $0"
echo ""
echo -e "${GREEN}🎉 All done!${NC}"
echo ""
