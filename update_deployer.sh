#!/bin/bash
################################################################################
# DEPLOYER SELF-UPDATE SCRIPT
# Updates the deployer toolkit from git and optionally rebuilds deployments
# 
# Usage: sudo bash update_deployer.sh
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

# Get deployer directory (where this script is)
DEPLOYER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║           🔄 DEPLOYER SELF-UPDATE TOOL 🔄                     ║"
    echo "║                                                                ║"
    echo "║       Update Deployer Scripts & Rebuild Deployments           ║"
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

find_deployments() {
    # Find all deployments that were created by this deployer
    local found_dirs=()
    
    # Check common deployment locations
    for base_path in /opt/* /var/www/* /home/*/app /srv/*; do
        if [ -d "$base_path/backend" ] && [ -d "$base_path/frontend" ]; then
            # Skip if it's the deployer directory itself
            if [ "$base_path" != "$DEPLOYER_DIR" ]; then
                found_dirs+=("$base_path")
            fi
        fi
    done
    
    # Also check supervisor for running apps
    if command -v supervisorctl &> /dev/null; then
        local config_files=$(find /etc/supervisor/conf.d -name "*.conf" 2>/dev/null)
        for config_file in $config_files; do
            local app_dirs=$(grep "directory=" "$config_file" | cut -d= -f2)
            for app_dir in $app_dirs; do
                local parent_dir=$(dirname "$app_dir" 2>/dev/null)
                if [ -d "$parent_dir/backend" ] && [ -d "$parent_dir/frontend" ]; then
                    # Skip deployer directory
                    if [ "$parent_dir" != "$DEPLOYER_DIR" ]; then
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

# Show current deployer info
echo ""
echo -e "${BOLD}Current Deployer Status:${NC}"
echo -e "  📂 Location: ${CYAN}$DEPLOYER_DIR${NC}"

# Check if deployer is a git repository
if [ ! -d "$DEPLOYER_DIR/.git" ]; then
    print_error "Deployer directory is not a git repository"
    echo ""
    echo "To use this script, the deployer must be in a git repository."
    echo "Initialize git in $DEPLOYER_DIR or clone from a repository."
    exit 1
fi

cd "$DEPLOYER_DIR"

# Show git info
echo -e "  🌿 Branch: ${CYAN}$(git branch --show-current)${NC}"
echo -e "  📝 Commit: ${CYAN}$(git rev-parse --short HEAD)${NC}"
echo -e "  🔗 Remote: ${CYAN}$(git remote get-url origin 2>/dev/null || echo 'No remote')${NC}"
echo ""

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD --; then
    print_warning "You have uncommitted changes in the deployer"
    echo ""
    git status --short
    echo ""
    
    if ask_yes_no "Stash these changes before updating?" "Y"; then
        git stash save "Auto-stash before deployer update $(date +%Y%m%d_%H%M%S)"
        print_success "Changes stashed"
    else
        print_error "Cannot update with uncommitted changes"
        exit 1
    fi
fi

################################################################################
# UPDATE DEPLOYER
################################################################################

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Step 1: Update Deployer Scripts${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

print_info "Fetching latest changes from git..."
git fetch origin

# Check if there are updates
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u} 2>/dev/null || echo $LOCAL)

if [ "$LOCAL" = "$REMOTE" ]; then
    print_success "Deployer is already up to date"
else
    print_info "Updates available. Pulling latest changes..."
    echo ""
    
    # Show what's new
    echo -e "${CYAN}New commits:${NC}"
    git log --oneline HEAD..@{u} | head -5
    echo ""
    
    if ask_yes_no "Pull these updates?" "Y"; then
        git pull
        print_success "Deployer updated successfully"
        
        # Show what changed
        echo ""
        echo -e "${CYAN}Files changed:${NC}"
        git diff --name-status $LOCAL HEAD | head -10
    else
        print_info "Update cancelled"
        exit 0
    fi
fi

################################################################################
# FIND DEPLOYMENTS
################################################################################

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Step 2: Scan for Existing Deployments${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

print_info "Scanning for deployments..."
deployment_dirs=$(find_deployments)

if [ -z "$deployment_dirs" ]; then
    print_warning "No deployments found on this system"
    echo ""
    echo "Would you like to deploy a new application?"
    echo ""
    
    if ask_yes_no "Run deployment wizard?" "N"; then
        echo ""
        print_info "Available deployers:"
        echo ""
        echo "  1) auto_deploy.sh - Basic FastAPI + React deployment"
        echo "  2) auto_deploy_auction.sh - Ballypatrick Auctions deployment"
        echo ""
        read -p "Select deployer (1-2) or 0 to exit: " DEPLOYER_CHOICE
        
        case $DEPLOYER_CHOICE in
            1)
                bash "$DEPLOYER_DIR/auto_deploy.sh"
                ;;
            2)
                bash "$DEPLOYER_DIR/auto_deploy_auction.sh"
                ;;
            *)
                echo "Exiting..."
                exit 0
                ;;
        esac
    fi
    exit 0
fi

# Convert to array
IFS=' ' read -r -a deployments <<< "$deployment_dirs"

echo ""
print_success "Found ${#deployments[@]} deployment(s)"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

counter=1
for app_dir in "${deployments[@]}"; do
    # Get app info
    app_name=$(basename "$app_dir")
    
    # Check if has git
    git_info="No git"
    if [ -d "$app_dir/.git" ]; then
        cd "$app_dir"
        branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        git_info="$branch@$commit"
    fi
    
    # Check service status
    service_status="⚫ Stopped"
    if command -v supervisorctl &> /dev/null; then
        if supervisorctl status 2>/dev/null | grep -q "RUNNING" | grep -q "$app_name\|backend\|frontend"; then
            service_status="🟢 Running"
        fi
    fi
    
    echo -e "${WHITE}[$counter]${NC} ${BOLD}$app_dir${NC}"
    echo -e "    Git: ${CYAN}$git_info${NC}  |  Status: $service_status"
    echo ""
    
    ((counter++))
done

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

################################################################################
# REBUILD DEPLOYMENTS
################################################################################

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Step 3: Rebuild Deployments${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if ! ask_yes_no "Would you like to rebuild any deployments with updated deployer?" "Y"; then
    echo ""
    print_info "No rebuilds requested"
    echo ""
    print_success "Deployer updated successfully!"
    echo ""
    echo -e "${CYAN}To rebuild deployments later, run:${NC}"
    echo "  sudo bash $DEPLOYER_DIR/update_deployer.sh"
    echo ""
    exit 0
fi

echo ""
echo "Select deployment(s) to rebuild:"
echo ""
echo "  a) All deployments"
echo "  s) Select specific deployment(s)"
echo "  n) None"
echo ""
read -p "Your choice (a/s/n): " REBUILD_CHOICE

case $REBUILD_CHOICE in
    [Aa])
        REBUILD_INDICES=($(seq 1 ${#deployments[@]}))
        ;;
    [Ss])
        echo ""
        read -p "Enter deployment numbers (e.g., 1 3 5): " REBUILD_INPUT
        IFS=' ' read -r -a REBUILD_INDICES <<< "$REBUILD_INPUT"
        ;;
    *)
        print_info "No rebuilds requested"
        exit 0
        ;;
esac

# Rebuild selected deployments
for index in "${REBUILD_INDICES[@]}"; do
    if [ "$index" -lt 1 ] || [ "$index" -gt ${#deployments[@]} ]; then
        print_warning "Invalid index: $index, skipping..."
        continue
    fi
    
    SELECTED_DIR="${deployments[$((index-1))]}"
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Rebuilding: $SELECTED_DIR${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Git pull if repository
    if [ -d "$SELECTED_DIR/.git" ]; then
        print_info "Pulling latest code..."
        cd "$SELECTED_DIR"
        git pull 2>&1 | tail -3
    fi
    
    # Update backend dependencies
    if [ -f "$SELECTED_DIR/backend/requirements.txt" ]; then
        print_info "Updating backend dependencies..."
        cd "$SELECTED_DIR/backend"
        pip3 install -r requirements.txt --upgrade -q 2>&1 | tail -2
    fi
    
    # Update frontend dependencies
    if [ -f "$SELECTED_DIR/frontend/package.json" ]; then
        print_info "Updating frontend dependencies..."
        cd "$SELECTED_DIR/frontend"
        
        if [ -f "yarn.lock" ]; then
            yarn install --silent 2>&1 | tail -2
        else
            npm install --silent 2>&1 | tail -2
        fi
    fi
    
    # Restart services
    print_info "Restarting services..."
    app_name=$(basename "$SELECTED_DIR")
    
    # Try to restart specific services
    for service_name in "$app_name-backend" "$app_name-frontend" "backend" "frontend"; do
        supervisorctl restart "$service_name" 2>/dev/null && break
    done
    
    sleep 2
    
    print_success "Rebuild complete for $SELECTED_DIR"
done

################################################################################
# COMPLETION
################################################################################

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✓ All Updates Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show deployer status
cd "$DEPLOYER_DIR"
echo -e "  ${BOLD}Deployer:${NC} Updated to $(git rev-parse --short HEAD)"
echo -e "  ${BOLD}Deployments:${NC} ${#REBUILD_INDICES[@]} rebuilt"
echo ""

# Show service status
if command -v supervisorctl &> /dev/null; then
    echo -e "${CYAN}Current Service Status:${NC}"
    supervisorctl status 2>/dev/null | grep -E "(backend|frontend)" | head -10
    echo ""
fi

echo -e "${CYAN}📚 Useful commands:${NC}"
echo ""
echo -e "  ${WHITE}# Update deployer again${NC}"
echo -e "  sudo bash $DEPLOYER_DIR/update_deployer.sh"
echo ""
echo -e "  ${WHITE}# Deploy new application${NC}"
echo -e "  sudo bash $DEPLOYER_DIR/auto_deploy_auction.sh"
echo ""
echo -e "  ${WHITE}# Check services${NC}"
echo -e "  sudo supervisorctl status"
echo ""
echo -e "${GREEN}🎉 All done!${NC}"
echo ""
