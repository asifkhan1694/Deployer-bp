#!/bin/bash
################################################################################
# APPLICATION UPDATE SCRIPT
# Updates deployed applications from their own git repositories
# 
# Usage: sudo bash update_application.sh
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
    echo "║         🔄 APPLICATION UPDATE TOOL 🔄                         ║"
    echo "║                                                                ║"
    echo "║       Update Deployed Applications from Git                    ║"
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

find_applications() {
    # Find all applications with backend/frontend
    local found_dirs=()
    
    # Check common deployment locations
    for base_path in /app /opt/* /var/www/* /home/*/* /srv/*; do
        if [ -d "$base_path/backend" ] && [ -d "$base_path/frontend" ]; then
            # Only include if it's a git repository
            if [ -d "$base_path/.git" ]; then
                found_dirs+=("$base_path")
            fi
        fi
    done
    
    # Also check supervisor configs
    if command -v supervisorctl &> /dev/null; then
        local config_files=$(find /etc/supervisor/conf.d -name "*.conf" 2>/dev/null)
        for config_file in $config_files; do
            local app_dirs=$(grep "directory=" "$config_file" | cut -d= -f2)
            for app_dir in $app_dirs; do
                local parent_dir=$(dirname "$app_dir" 2>/dev/null)
                if [ -d "$parent_dir/.git" ] && [ -d "$parent_dir/backend" ] && [ -d "$parent_dir/frontend" ]; then
                    # Check if not already in list
                    local already_found=false
                    for existing in "${found_dirs[@]}"; do
                        if [ "$existing" = "$parent_dir" ]; then
                            already_found=true
                            break
                        fi
                    done
                    if [ "$already_found" = false ]; then
                        found_dirs+=("$parent_dir")
                    fi
                fi
            done
        done
    fi
    
    echo "${found_dirs[@]}"
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

# Scan for applications
echo ""
print_info "Scanning for deployed applications..."
echo ""

application_dirs=$(find_applications)

if [ -z "$application_dirs" ]; then
    print_error "No deployed applications with git repositories found"
    echo ""
    echo "This script looks for applications with:"
    echo "  • backend/ and frontend/ directories"
    echo "  • .git/ directory (git repository)"
    echo ""
    echo "Common locations checked:"
    echo "  • /app"
    echo "  • /opt/*"
    echo "  • /var/www/*"
    echo "  • /home/*/*"
    echo "  • /srv/*"
    echo ""
    
    # Check if current directory is an application
    CURRENT_DIR=$(pwd)
    if [ -d "$CURRENT_DIR/backend" ] && [ -d "$CURRENT_DIR/frontend" ] && [ -d "$CURRENT_DIR/.git" ]; then
        print_info "Current directory appears to be an application!"
        echo ""
        echo "  📂 $CURRENT_DIR"
        echo ""
        
        if ask_yes_no "Update this application?" "Y"; then
            application_dirs=("$CURRENT_DIR")
        else
            exit 0
        fi
    else
        echo "If your application is elsewhere, you can:"
        echo "  1. cd to your application directory and run this script"
        echo "  2. Or specify the path when prompted"
        echo ""
        read -p "Enter application directory path (or press Enter to exit): " manual_path
        
        if [ -z "$manual_path" ]; then
            exit 0
        fi
        
        if [ ! -d "$manual_path/backend" ] || [ ! -d "$manual_path/frontend" ]; then
            print_error "Invalid application directory. Must contain 'backend' and 'frontend' folders."
            exit 1
        fi
        
        if [ ! -d "$manual_path/.git" ]; then
            print_warning "Directory is not a git repository"
            if ! ask_yes_no "Continue anyway?" "N"; then
                exit 1
            fi
        fi
        
        application_dirs=("$manual_path")
    fi
fi

# Convert to array
IFS=' ' read -r -a applications <<< "$application_dirs"

# Display found applications
echo -e "${BOLD}${GREEN}Found ${#applications[@]} application(s) with git repositories:${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

counter=1
for app_dir in "${applications[@]}"; do
    cd "$app_dir"
    
    app_name=$(basename "$app_dir")
    branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    remote=$(git remote get-url origin 2>/dev/null || echo "No remote")
    
    # Check service status
    service_status="⚫ Stopped"
    if command -v supervisorctl &> /dev/null; then
        if supervisorctl status 2>/dev/null | grep -E "$app_name|backend|frontend" | grep -q "RUNNING"; then
            service_status="🟢 Running"
        fi
    fi
    
    # Get size
    size=$(du -sh "$app_dir" 2>/dev/null | cut -f1)
    
    # Check if updates available
    git fetch origin 2>/dev/null || true
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse @{u} 2>/dev/null || echo $LOCAL)
    
    updates_status="✓ Up to date"
    if [ "$LOCAL" != "$REMOTE" ]; then
        updates_status="⚠ Updates available"
    fi
    
    echo -e "${WHITE}[$counter]${NC} ${BOLD}$app_dir${NC}"
    echo -e "    ${CYAN}Repository:${NC} $remote"
    echo -e "    ${CYAN}Branch:${NC} $branch  |  ${CYAN}Commit:${NC} $commit  |  ${CYAN}Status:${NC} $service_status"
    echo -e "    ${CYAN}Size:${NC} $size  |  $updates_status"
    echo ""
    
    ((counter++))
done

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Select application
if [ ${#applications[@]} -eq 1 ]; then
    SELECTION=1
    print_info "Only one application found, selecting automatically..."
else
    read -p "Select application to update (1-${#applications[@]}) or 0 to exit: " SELECTION
    
    if [ "$SELECTION" -eq 0 ]; then
        echo "Update cancelled"
        exit 0
    fi
    
    if [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#applications[@]} ]; then
        print_error "Invalid selection"
        exit 1
    fi
fi

SELECTED_DIR="${applications[$((SELECTION-1))]}"

echo ""
echo -e "${BOLD}Selected Application:${NC}"
echo -e "  📂 ${GREEN}$SELECTED_DIR${NC}"

cd "$SELECTED_DIR"
echo -e "  🔗 Repository: ${CYAN}$(git remote get-url origin)${NC}"
echo -e "  🌿 Branch: ${CYAN}$(git branch --show-current)${NC}"
echo -e "  📝 Current Commit: ${CYAN}$(git rev-parse --short HEAD)${NC}"
echo ""

# Show what's new
git fetch origin 2>/dev/null || true
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo $LOCAL)

if [ "$LOCAL" != "$REMOTE" ]; then
    echo -e "${CYAN}New commits available:${NC}"
    git log --oneline HEAD..@{u} | head -5
    echo ""
fi

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
echo -e "${BOLD}Starting Application Update${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Step 1: Create backup
echo ""
print_info "Step 1/5: Creating backup..."

BACKUP_DIR="/app_backups"
mkdir -p $BACKUP_DIR

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup_${TIMESTAMP}_$(basename $SELECTED_DIR)"

cp -r "$SELECTED_DIR" "$BACKUP_PATH"
print_success "Backup created at: $BACKUP_PATH"

# Step 2: Stash local changes if any
echo ""
print_info "Step 2/5: Checking for local changes..."

cd "$SELECTED_DIR"
if ! git diff-index --quiet HEAD --; then
    print_warning "Local changes detected, stashing..."
    git stash save "Auto-stash before update $TIMESTAMP"
    print_success "Changes stashed"
else
    print_success "No local changes"
fi

# Step 3: Pull latest code
echo ""
print_info "Step 3/5: Pulling latest code from git..."

git pull 2>&1 | tail -5

NEW_COMMIT=$(git rev-parse --short HEAD)
print_success "Updated to commit: $NEW_COMMIT"

# Show what changed
echo ""
echo -e "${CYAN}Files changed:${NC}"
git diff --name-status $LOCAL HEAD | head -10

# Step 4: Update dependencies
echo ""
print_info "Step 4/5: Updating dependencies..."

# Backend
if [ -f "$SELECTED_DIR/backend/requirements.txt" ]; then
    echo ""
    print_info "Updating backend dependencies..."
    cd "$SELECTED_DIR/backend"
    pip3 install -r requirements.txt --upgrade -q 2>&1 | tail -3
    print_success "Backend dependencies updated"
fi

# Frontend
if [ -f "$SELECTED_DIR/frontend/package.json" ]; then
    echo ""
    print_info "Updating frontend dependencies..."
    cd "$SELECTED_DIR/frontend"
    
    if [ -f "yarn.lock" ]; then
        print_info "Using Yarn..."
        yarn install --silent 2>&1 | tail -2
    else
        print_info "Using npm..."
        npm install --silent 2>&1 | tail -2
    fi
    print_success "Frontend dependencies updated"
fi

# Step 5: Restart services
echo ""
print_info "Step 5/5: Restarting services..."

app_name=$(basename "$SELECTED_DIR")

if command -v supervisorctl &> /dev/null; then
    # Try common service name patterns
    restarted=false
    for service_pattern in "$app_name-backend" "$app_name-frontend" "backend" "frontend" "$app_name:*"; do
        if supervisorctl status 2>/dev/null | grep -q "$service_pattern"; then
            supervisorctl restart "$service_pattern" 2>&1 | grep -E "(started|ERROR)" || true
            restarted=true
        fi
    done
    
    if [ "$restarted" = false ]; then
        print_warning "Specific services not found, trying restart all..."
        supervisorctl restart all 2>&1 | grep -E "(started|ERROR)" | head -5 || true
    fi
    
    print_success "Services restarted"
else
    print_warning "Supervisor not found, please restart services manually"
fi

# Wait for services to start
sleep 3

################################################################################
# COMPLETION & HEALTH CHECK
################################################################################

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✓ Update Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd "$SELECTED_DIR"
echo -e "  📂 ${BOLD}Application:${NC} $SELECTED_DIR"
echo -e "  📝 ${BOLD}Updated from:${NC} $LOCAL → $NEW_COMMIT"
echo -e "  💾 ${BOLD}Backup:${NC} $BACKUP_PATH"
echo ""

# Health check
echo -e "${CYAN}Checking services...${NC}"
if command -v supervisorctl &> /dev/null; then
    supervisorctl status 2>/dev/null | grep -E "(backend|frontend)" | head -10
fi

echo ""
echo -e "${CYAN}📊 Useful commands:${NC}"
echo ""
echo -e "  ${WHITE}# View recent commits${NC}"
echo -e "  cd $SELECTED_DIR && git log --oneline -10"
echo ""
echo -e "  ${WHITE}# View application logs${NC}"
echo -e "  tail -f /var/log/supervisor/*.err.log"
echo ""
echo -e "  ${WHITE}# Rollback if needed${NC}"
echo -e "  sudo rm -rf $SELECTED_DIR"
echo -e "  sudo cp -r $BACKUP_PATH $SELECTED_DIR"
echo -e "  sudo supervisorctl restart all"
echo ""
echo -e "  ${WHITE}# Update again${NC}"
echo -e "  sudo bash $0"
echo ""
echo -e "${GREEN}🎉 All done!${NC}"
echo ""
