#!/bin/bash
################################################################################
# ROLLBACK SCRIPT
# Restore application to a previous backup
# 
# Usage: sudo bash rollback_deployment.sh
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

APP_DIR="/app"
BACKUP_DIR="/app_backups"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║              ⏮️  DEPLOYMENT ROLLBACK TOOL ⏮️                  ║"
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

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    print_error "No backups found at: $BACKUP_DIR"
    echo ""
    echo "Backups are created automatically when you run:"
    echo "  sudo bash update_deployment.sh --backup"
    exit 1
fi

# List available backups
echo ""
echo -e "${BOLD}Available Backups:${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

backups=($(ls -t $BACKUP_DIR))

if [ ${#backups[@]} -eq 0 ]; then
    print_error "No backups found"
    exit 1
fi

# Show backups with details
counter=1
for backup in "${backups[@]}"; do
    backup_path="$BACKUP_DIR/$backup"
    backup_date=$(echo $backup | sed 's/backup_//')
    
    # Format date nicely
    year=${backup_date:0:4}
    month=${backup_date:4:2}
    day=${backup_date:6:2}
    hour=${backup_date:9:2}
    minute=${backup_date:11:2}
    
    formatted_date="$year-$month-$day $hour:$minute"
    
    # Get backup size
    size=$(du -sh $backup_path 2>/dev/null | cut -f1)
    
    # Check if has database backup
    db_status="No DB"
    if [ -d "$backup_path/db_backup" ]; then
        db_status="With DB"
    fi
    
    echo -e "  ${WHITE}[$counter]${NC} $formatted_date  |  ${CYAN}$size${NC}  |  $db_status"
    ((counter++))
done

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Select backup
read -p "Select backup number to restore (1-${#backups[@]}) or 0 to cancel: " SELECTION

if [ "$SELECTION" -eq 0 ]; then
    echo "Rollback cancelled"
    exit 0
fi

if [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#backups[@]} ]; then
    print_error "Invalid selection"
    exit 1
fi

# Get selected backup
SELECTED_BACKUP="${backups[$((SELECTION-1))]}"
BACKUP_PATH="$BACKUP_DIR/$SELECTED_BACKUP"

echo ""
echo -e "${BOLD}Selected Backup:${NC}"
echo -e "  📁 $SELECTED_BACKUP"
echo -e "  📂 $BACKUP_PATH"
echo ""

print_warning "This will replace your current deployment!"
echo ""

if ! ask_yes_no "Are you sure you want to rollback?" "N"; then
    echo "Rollback cancelled"
    exit 0
fi

# Create a backup of current state before rollback
echo ""
print_info "Creating safety backup of current state..."
SAFETY_BACKUP="$BACKUP_DIR/before_rollback_$(date +%Y%m%d_%H%M%S)"
cp -r $APP_DIR $SAFETY_BACKUP
print_success "Safety backup created: $SAFETY_BACKUP"

# Stop services
echo ""
print_info "Stopping services..."
supervisorctl stop all 2>&1 | grep -E "stopped|ERROR" || true

# Restore code
echo ""
print_info "Restoring application code..."
rm -rf $APP_DIR
cp -r $BACKUP_PATH $APP_DIR

# Remove db_backup folder from app (if exists)
rm -rf $APP_DIR/db_backup 2>/dev/null || true

print_success "Application code restored"

# Restore database
if [ -d "$BACKUP_PATH/db_backup" ]; then
    echo ""
    if ask_yes_no "Restore database as well?" "Y"; then
        print_info "Restoring database..."
        
        # Get database name from .env
        if [ -f "$APP_DIR/backend/.env" ]; then
            source $APP_DIR/backend/.env
            
            print_warning "This will replace database: $DB_NAME"
            if ask_yes_no "Continue with database restore?" "Y"; then
                mongorestore --db $DB_NAME --drop $BACKUP_PATH/db_backup/$DB_NAME 2>&1 | grep -E "(done|ERROR)" || true
                print_success "Database restored"
            fi
        else
            print_warning "Could not find .env file, skipping database restore"
        fi
    fi
fi

# Restart services
echo ""
print_info "Restarting services..."
supervisorctl start all 2>&1 | grep -E "started|ERROR" || true

sleep 3

# Health check
echo ""
print_info "Running health checks..."

if curl -s http://localhost:8001/api/ > /dev/null 2>&1; then
    print_success "Backend API is responding"
else
    print_warning "Backend API not responding yet"
fi

if curl -s http://localhost:3000 > /dev/null 2>&1; then
    print_success "Frontend is responding"
else
    print_warning "Frontend not responding yet"
fi

# Success message
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✓ Rollback Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ⏮️  Restored to: ${BOLD}$SELECTED_BACKUP${NC}"
echo -e "  💾 Safety backup: ${BOLD}$SAFETY_BACKUP${NC}"
echo ""
echo -e "${CYAN}Service Status:${NC}"
supervisorctl status 2>&1 | head -10
echo ""
echo -e "${YELLOW}If something is wrong, you can restore from safety backup:${NC}"
echo -e "  rm -rf $APP_DIR"
echo -e "  cp -r $SAFETY_BACKUP $APP_DIR"
echo -e "  sudo supervisorctl restart all"
echo ""
