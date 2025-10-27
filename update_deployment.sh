#!/bin/bash
################################################################################
# DEPLOYMENT UPDATE SCRIPT
# Update existing deployment with latest code from GitHub
# 
# Usage: 
#   sudo bash update_deployment.sh                    # Update from current repo
#   sudo bash update_deployment.sh --new-repo         # Switch to new repo
#   sudo bash update_deployment.sh --backup           # Create backup before update
################################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

APP_DIR="/app"
BACKUP_DIR="/app_backups"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║              🔄 DEPLOYMENT UPDATE TOOL 🔄                     ║"
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

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$timestamp"
    
    echo ""
    print_info "Creating backup..."
    
    mkdir -p $BACKUP_DIR
    
    # Backup application code
    cp -r $APP_DIR $backup_path
    
    # Backup database
    print_info "Backing up database..."
    if [ -f "$APP_DIR/backend/.env" ]; then
        source $APP_DIR/backend/.env
        mongodump --db $DB_NAME --out $backup_path/db_backup --quiet 2>/dev/null || true
    fi
    
    print_success "Backup created at: $backup_path"
    echo "  📁 Code: $backup_path"
    echo "  🗄️  Database: $backup_path/db_backup"
    
    # Keep only last 5 backups
    cd $BACKUP_DIR
    ls -t | tail -n +6 | xargs rm -rf 2>/dev/null || true
}

update_from_git() {
    echo ""
    print_info "Updating from GitHub..."
    
    cd $APP_DIR
    
    # Show current status
    echo ""
    print_info "Current branch: $(git branch --show-current)"
    print_info "Current commit: $(git rev-parse --short HEAD)"
    
    # Stash any local changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "Local changes detected, stashing..."
        git stash
    fi
    
    # Pull latest changes
    print_info "Pulling latest changes..."
    git pull
    
    # Show new status
    echo ""
    print_success "Updated to commit: $(git rev-parse --short HEAD)"
    
    # Show what changed
    echo ""
    print_info "Recent changes:"
    git log --oneline -5
}

switch_repository() {
    echo ""
    print_warning "Switching to a new repository will replace all code!"
    echo ""
    
    read -p "Enter new GitHub repository URL: " NEW_REPO
    read -p "Enter branch name (default: main): " NEW_BRANCH
    NEW_BRANCH=${NEW_BRANCH:-main}
    
    echo ""
    print_info "New repository: $NEW_REPO"
    print_info "Branch: $NEW_BRANCH"
    echo ""
    
    if ask_yes_no "Confirm switch to new repository?" "N"; then
        # Create backup first
        create_backup
        
        # Remove old code
        print_info "Removing old code..."
        rm -rf $APP_DIR
        
        # Clone new repo
        print_info "Cloning new repository..."
        git clone -b $NEW_BRANCH $NEW_REPO $APP_DIR
        
        print_success "Repository switched successfully"
        
        # Need to reconfigure
        print_warning "You may need to reconfigure environment files!"
        return 0
    else
        print_info "Repository switch cancelled"
        return 1
    fi
}

update_dependencies() {
    echo ""
    print_info "Updating dependencies..."
    
    # Backend dependencies
    if [ -f "$APP_DIR/backend/requirements.txt" ]; then
        echo ""
        print_info "Updating Python dependencies..."
        cd $APP_DIR/backend
        pip3 install -r requirements.txt --upgrade 2>&1 | grep -E "(Successfully|Requirement already|ERROR)" || true
        print_success "Python dependencies updated"
    fi
    
    # Frontend dependencies
    if [ -f "$APP_DIR/frontend/package.json" ]; then
        echo ""
        print_info "Updating frontend dependencies..."
        cd $APP_DIR/frontend
        
        # Check if using yarn or npm
        if [ -f "yarn.lock" ]; then
            print_info "Using Yarn..."
            yarn install 2>&1 | tail -5
        else
            print_info "Using npm..."
            npm install 2>&1 | tail -5
        fi
        print_success "Frontend dependencies updated"
    fi
}

run_migrations() {
    echo ""
    if ask_yes_no "Run database migrations/seed scripts?" "N"; then
        cd $APP_DIR/backend
        
        # Check for migration or seed scripts
        if [ -f "seed.py" ]; then
            print_info "Running seed scripts..."
            python3 seed.py 2>&1 || print_warning "Seed script completed with warnings"
        fi
        
        if [ -f "migrate.py" ]; then
            print_info "Running migrations..."
            python3 migrate.py 2>&1 || print_warning "Migrations completed with warnings"
        fi
        
        print_success "Database updates complete"
    fi
}

restart_services() {
    echo ""
    print_info "Restarting services..."
    
    # Check if supervisor is running
    if command -v supervisorctl &> /dev/null; then
        supervisorctl restart all 2>&1 | grep -E "(started|ERROR)" || true
        
        sleep 3
        
        echo ""
        print_info "Service status:"
        supervisorctl status 2>&1 | head -10
        
        print_success "Services restarted"
    else
        print_warning "Supervisor not found, skipping service restart"
    fi
}

health_check() {
    echo ""
    print_info "Running health checks..."
    
    sleep 5
    
    # Check backend
    if curl -s http://localhost:8001/api/ > /dev/null 2>&1; then
        print_success "Backend API is responding"
    else
        print_warning "Backend API not responding (may need more time)"
    fi
    
    # Check frontend
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        print_success "Frontend is responding"
    else
        print_warning "Frontend not responding (may need more time)"
    fi
}

show_logs() {
    echo ""
    if ask_yes_no "Show recent logs?" "N"; then
        echo ""
        echo -e "${CYAN}━━━ Backend Logs ━━━${NC}"
        tail -n 20 /var/log/supervisor/*.err.log 2>/dev/null || echo "No logs found"
    fi
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

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    print_error "Application directory not found: $APP_DIR"
    echo ""
    echo "Please run the initial deployment first:"
    echo "  sudo bash auto_deploy_auction.sh"
    exit 1
fi

# Parse arguments
NEW_REPO_MODE=false
BACKUP_MODE=false

for arg in "$@"; do
    case $arg in
        --new-repo)
            NEW_REPO_MODE=true
            ;;
        --backup)
            BACKUP_MODE=true
            ;;
        --help)
            echo "Usage:"
            echo "  sudo bash update_deployment.sh                # Update from current repo"
            echo "  sudo bash update_deployment.sh --new-repo     # Switch to new repository"
            echo "  sudo bash update_deployment.sh --backup       # Create backup before update"
            exit 0
            ;;
    esac
done

# Display current status
echo ""
echo -e "${BOLD}Current Deployment Status:${NC}"
echo ""
cd $APP_DIR
echo -e "  📂 Location:    $APP_DIR"
echo -e "  🔗 Repository:  $(git config --get remote.origin.url)"
echo -e "  🌿 Branch:      $(git branch --show-current)"
echo -e "  📝 Commit:      $(git rev-parse --short HEAD) - $(git log -1 --pretty=%B | head -1)"
echo ""

# Choose action
if [ "$NEW_REPO_MODE" = true ]; then
    print_info "New repository mode enabled"
    switch_repository
    SWITCHED_REPO=true
else
    echo "What would you like to do?"
    echo ""
    echo "  1) Update from current repository (git pull)"
    echo "  2) Switch to a new repository"
    echo "  3) Exit"
    echo ""
    read -p "Choose option (1-3): " CHOICE
    
    case $CHOICE in
        1)
            SWITCHED_REPO=false
            ;;
        2)
            switch_repository && SWITCHED_REPO=true || exit 0
            ;;
        3)
            echo "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
fi

# Create backup if requested or before major changes
if [ "$BACKUP_MODE" = true ] || [ "$SWITCHED_REPO" = true ]; then
    create_backup
elif ask_yes_no "Create backup before updating?" "Y"; then
    create_backup
fi

# Update from git (if not switched repo)
if [ "$SWITCHED_REPO" = false ]; then
    update_from_git
fi

# Update dependencies
if ask_yes_no "Update dependencies?" "Y"; then
    update_dependencies
fi

# Run migrations
if [ "$SWITCHED_REPO" = true ]; then
    print_warning "New repository detected - you may need to:"
    echo "  1. Update environment variables in /app/backend/.env"
    echo "  2. Update environment variables in /app/frontend/.env"
    echo "  3. Run seed scripts manually"
    echo "  4. Update supervisor configuration if ports changed"
fi

run_migrations

# Restart services
if ask_yes_no "Restart services now?" "Y"; then
    restart_services
    health_check
fi

# Show logs
show_logs

# Success message
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✓ Update Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd $APP_DIR
echo -e "  📝 Current commit: ${BOLD}$(git rev-parse --short HEAD)${NC}"
echo -e "  🌿 Current branch: ${BOLD}$(git branch --show-current)${NC}"
echo ""

if [ -d "$BACKUP_DIR" ]; then
    echo -e "  💾 Backups available in: $BACKUP_DIR"
    echo -e "     Latest: $(ls -t $BACKUP_DIR | head -1)"
    echo ""
fi

echo -e "${CYAN}Useful commands:${NC}"
echo ""
echo -e "  ${WHITE}# Check service status${NC}"
echo -e "  sudo supervisorctl status"
echo ""
echo -e "  ${WHITE}# View logs${NC}"
echo -e "  tail -f /var/log/supervisor/*.err.log"
echo ""
echo -e "  ${WHITE}# Rollback to backup${NC}"
echo -e "  sudo bash rollback_deployment.sh"
echo ""

echo -e "${GREEN}🎉 All done!${NC}"
echo ""
