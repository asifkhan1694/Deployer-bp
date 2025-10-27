#!/bin/bash
################################################################################
# UNIVERSAL DEPLOYMENT UPDATER
# Scans system for deployed applications and updates selected one
# 
# Usage: sudo bash universal_update.sh
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

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║         🔍 UNIVERSAL DEPLOYMENT UPDATER 🔍                    ║"
    echo "║                                                                ║"
    echo "║         Scan and Update Any Deployed Application               ║"
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

detect_app_type() {
    local dir=$1
    local app_type="unknown"
    
    # Check backend
    if [ -f "$dir/backend/server.py" ]; then
        if grep -q "auction\|collection\|lot" "$dir/backend/server.py" 2>/dev/null; then
            app_type="auction"
        else
            app_type="fastapi"
        fi
    elif [ -f "$dir/backend/package.json" ]; then
        app_type="nodejs"
    fi
    
    # Check if has routes directory (complex app)
    if [ -d "$dir/backend/routes" ]; then
        app_type="${app_type}_complex"
    fi
    
    echo "$app_type"
}

get_git_info() {
    local dir=$1
    local info="No git"
    
    if [ -d "$dir/.git" ]; then
        cd "$dir"
        local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        info="$branch@$commit"
    fi
    
    echo "$info"
}

scan_deployments() {
    echo -e "${CYAN}🔍 Scanning system for deployments...${NC}"
    echo ""
    
    # Common deployment locations
    search_paths=(
        "/app"
        "/opt/*"
        "/var/www/*"
        "/home/*/app"
        "/srv/*"
    )
    
    # Find all potential deployments
    deployments=()
    
    for path_pattern in "${search_paths[@]}"; do
        for backend_dir in $(find $(dirname $(dirname "$path_pattern")) -maxdepth 3 -type d -name "backend" 2>/dev/null); do
            app_dir=$(dirname "$backend_dir")
            
            # Skip if already in list
            if [[ " ${deployments[@]} " =~ " ${app_dir} " ]]; then
                continue
            fi
            
            # Verify it has both backend and frontend
            if [ -d "$app_dir/frontend" ]; then
                deployments+=("$app_dir")
            fi
        done
    done
    
    # Also check supervisor for running apps
    if command -v supervisorctl &> /dev/null; then
        supervisor_apps=$(supervisorctl status 2>/dev/null | grep -E "(backend|frontend)" | awk '{print $1}' | sed 's/:.*//g' | uniq)
        
        for app in $supervisor_apps; do
            # Try to find the directory from supervisor config
            config_file=$(find /etc/supervisor/conf.d -name "*${app}*.conf" 2>/dev/null | head -1)
            if [ -n "$config_file" ]; then
                app_dir=$(grep "directory=" "$config_file" | cut -d= -f2 | xargs dirname 2>/dev/null)
                if [ -n "$app_dir" ] && [ -d "$app_dir" ]; then
                    if [[ ! " ${deployments[@]} " =~ " ${app_dir} " ]]; then
                        deployments+=("$app_dir")
                    fi
                fi
            fi
        done
    fi
    
    echo "${deployments[@]}"
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

# Scan for deployments
print_info "Scanning system for deployed applications..."
sleep 1

deployment_dirs=$(scan_deployments)

if [ -z "$deployment_dirs" ]; then
    print_error "No deployments found on this system"
    echo ""
    echo "This script looks for applications with both 'backend' and 'frontend' directories."
    echo ""
    echo "Common locations checked:"
    echo "  • /opt/*/backend"
    echo "  • /var/www/*/backend"
    echo "  • /home/*/app/backend"
    echo "  • /srv/*/backend"
    echo ""
    echo "If your deployment is elsewhere, please provide the path manually:"
    echo ""
    read -p "Enter deployment directory path (or press Enter to exit): " manual_path
    
    if [ -z "$manual_path" ]; then
        exit 0
    fi
    
    if [ ! -d "$manual_path/backend" ] || [ ! -d "$manual_path/frontend" ]; then
        print_error "Invalid deployment directory. Must contain 'backend' and 'frontend' folders."
        exit 1
    fi
    
    deployment_dirs=("$manual_path")
fi

# Convert to array
IFS=' ' read -r -a deployments <<< "$deployment_dirs"

# Display found deployments
echo ""
echo -e "${BOLD}${GREEN}Found ${#deployments[@]} deployment(s):${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

counter=1
for app_dir in "${deployments[@]}"; do
    app_type=$(detect_app_type "$app_dir")
    git_info=$(get_git_info "$app_dir")
    
    # Check if services are running
    app_name=$(basename "$app_dir")
    service_status="⚫ Stopped"
    
    if command -v supervisorctl &> /dev/null; then
        if supervisorctl status 2>/dev/null | grep -q "$app_name.*RUNNING\|backend.*RUNNING"; then
            service_status="🟢 Running"
        fi
    fi
    
    # Get size
    size=$(du -sh "$app_dir" 2>/dev/null | cut -f1)
    
    echo -e "${WHITE}[$counter]${NC} ${BOLD}$app_dir${NC}"
    echo -e "    Type: ${CYAN}$app_type${NC}  |  Git: ${CYAN}$git_info${NC}  |  Status: $service_status  |  Size: $size"
    echo ""
    
    ((counter++))
done

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Select deployment
if [ ${#deployments[@]} -eq 1 ]; then
    SELECTION=1
    print_info "Only one deployment found, selecting automatically..."
else
    read -p "Select deployment to update (1-${#deployments[@]}) or 0 to exit: " SELECTION
    
    if [ "$SELECTION" -eq 0 ]; then
        echo "Update cancelled"
        exit 0
    fi
    
    if [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#deployments[@]} ]; then
        print_error "Invalid selection"
        exit 1
    fi
fi

SELECTED_DIR="${deployments[$((SELECTION-1))]}"

echo ""
echo -e "${BOLD}Selected Deployment:${NC}"
echo -e "  📂 ${GREEN}$SELECTED_DIR${NC}"
echo ""

# Confirm update
if ! ask_yes_no "Proceed with update?" "Y"; then
    echo "Update cancelled"
    exit 0
fi

################################################################################
# UPDATE PROCESS
################################################################################

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Starting Update Process${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Step 1: Git pull (if git repo)
if [ -d "$SELECTED_DIR/.git" ]; then
    echo ""
    print_info "Step 1/4: Pulling latest code from git..."
    cd "$SELECTED_DIR"
    
    # Stash any local changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "Stashing local changes..."
        git stash
    fi
    
    git pull 2>&1 | tail -5
    print_success "Git pull complete"
else
    echo ""
    print_warning "Step 1/4: No git repository detected, skipping git pull"
fi

# Step 2: Update backend dependencies
if [ -f "$SELECTED_DIR/backend/requirements.txt" ]; then
    echo ""
    print_info "Step 2/4: Updating backend dependencies..."
    cd "$SELECTED_DIR/backend"
    pip3 install -r requirements.txt --upgrade -q 2>&1 | tail -3
    print_success "Backend dependencies updated"
else
    echo ""
    print_warning "Step 2/4: No requirements.txt found, skipping backend update"
fi

# Step 3: Update frontend dependencies
if [ -f "$SELECTED_DIR/frontend/package.json" ]; then
    echo ""
    print_info "Step 3/4: Updating frontend dependencies..."
    cd "$SELECTED_DIR/frontend"
    
    if [ -f "yarn.lock" ]; then
        print_info "Using Yarn..."
        yarn install --silent 2>&1 | tail -2
    else
        print_info "Using npm..."
        npm install --silent 2>&1 | tail -2
    fi
    print_success "Frontend dependencies updated"
else
    echo ""
    print_warning "Step 3/4: No package.json found, skipping frontend update"
fi

# Step 4: Restart services
echo ""
print_info "Step 4/4: Restarting services..."

# Try to find and restart services
app_name=$(basename "$SELECTED_DIR")
restarted=false

if command -v supervisorctl &> /dev/null; then
    # Try common service names
    for service_name in "$app_name-backend" "$app_name-frontend" "backend" "frontend" "$app_name"; do
        if supervisorctl status 2>/dev/null | grep -q "$service_name"; then
            supervisorctl restart "$service_name" 2>&1 | grep -E "(started|ERROR)" || true
            restarted=true
        fi
    done
    
    if [ "$restarted" = false ]; then
        print_warning "Could not find specific services, trying 'restart all'..."
        supervisorctl restart all 2>&1 | grep -E "(started|ERROR)" | head -5 || true
    fi
    
    print_success "Services restarted"
else
    print_warning "Supervisor not found, skipping service restart"
    echo "  You may need to restart services manually"
fi

# Wait for services to start
sleep 3

################################################################################
# COMPLETION
################################################################################

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✓ Update Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show updated status
if [ -d "$SELECTED_DIR/.git" ]; then
    cd "$SELECTED_DIR"
    echo -e "  ${BOLD}Updated to:${NC} $(git log -1 --oneline)"
    echo ""
fi

# Health check
echo -e "${CYAN}Checking services...${NC}"
if command -v supervisorctl &> /dev/null; then
    supervisorctl status 2>/dev/null | grep -E "(backend|frontend)" | head -10
fi

echo ""
echo -e "${CYAN}📊 Useful commands:${NC}"
echo ""
echo -e "  ${WHITE}# View logs${NC}"
echo -e "  tail -f /var/log/supervisor/*.err.log"
echo ""
echo -e "  ${WHITE}# Check services${NC}"
echo -e "  sudo supervisorctl status"
echo ""
echo -e "  ${WHITE}# Manual restart if needed${NC}"
echo -e "  sudo supervisorctl restart all"
echo ""
echo -e "${GREEN}🎉 All done!${NC}"
echo ""
