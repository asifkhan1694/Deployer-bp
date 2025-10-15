#!/bin/bash
# Deployment script for FastAPI + React Application
# Pulls latest code from git and deploys the application

set -e  # Exit on error

# Configuration
APP_DIR="${APP_DIR:-/opt/app}"
GIT_REPO="${GIT_REPO:-}"
GIT_BRANCH="${GIT_BRANCH:-main}"
VENV_PATH="${VENV_PATH:-$APP_DIR/venv}"
BACKUP_DIR="/opt/app_backups"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to create backup
create_backup() {
    if [ -d "$APP_DIR" ]; then
        log_step "Creating backup of current deployment..."
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"
        mkdir -p "$BACKUP_DIR"
        cp -r "$APP_DIR" "$BACKUP_PATH"
        log_info "Backup created at: $BACKUP_PATH"
        
        # Keep only last 5 backups
        cd "$BACKUP_DIR"
        ls -t | tail -n +6 | xargs -r rm -rf
    fi
}

# Function to rollback
rollback() {
    log_error "Deployment failed. Rolling back..."
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -n 1)
    if [ -n "$LATEST_BACKUP" ]; then
        rm -rf "$APP_DIR"
        cp -r "$BACKUP_DIR/$LATEST_BACKUP" "$APP_DIR"
        log_info "Rolled back to: $LATEST_BACKUP"
        restart_services
    else
        log_error "No backup found for rollback!"
    fi
    exit 1
}

# Set up error handling
trap rollback ERR

# Function to restart services
restart_services() {
    log_step "Restarting services..."
    
    if [ -f /etc/supervisor/conf.d/app.conf ]; then
        supervisorctl reread
        supervisorctl update
        supervisorctl restart backend
        supervisorctl restart frontend
        log_info "Services restarted via Supervisor"
    elif command -v pm2 &> /dev/null; then
        pm2 restart all
        log_info "Services restarted via PM2"
    else
        log_warn "No process manager found. Please restart services manually."
    fi
}

# Function to check service health
check_health() {
    log_step "Checking service health..."
    
    # Check backend
    sleep 5  # Give services time to start
    RETRIES=10
    for i in $(seq 1 $RETRIES); do
        if curl -f http://localhost:8001/api/ > /dev/null 2>&1; then
            log_info "Backend is healthy"
            break
        else
            if [ $i -eq $RETRIES ]; then
                log_error "Backend health check failed after $RETRIES attempts"
                return 1
            fi
            log_warn "Backend not ready, retrying... ($i/$RETRIES)"
            sleep 3
        fi
    done
    
    # Check frontend
    for i in $(seq 1 $RETRIES); do
        if curl -f http://localhost:3000 > /dev/null 2>&1; then
            log_info "Frontend is healthy"
            break
        else
            if [ $i -eq $RETRIES ]; then
                log_error "Frontend health check failed after $RETRIES attempts"
                return 1
            fi
            log_warn "Frontend not ready, retrying... ($i/$RETRIES)"
            sleep 3
        fi
    done
    
    return 0
}

echo "================================================"
echo "FastAPI + React Application Deployment"
echo "================================================"

# Check if git repo is set
if [ -z "$GIT_REPO" ] && [ ! -d "$APP_DIR/.git" ]; then
    log_error "GIT_REPO environment variable not set and no git repository found in $APP_DIR"
    log_info "Usage: GIT_REPO=<your-repo-url> ./deploy.sh"
    exit 1
fi

# Create backup
create_backup

# Clone or pull repository
if [ -d "$APP_DIR/.git" ]; then
    log_step "Pulling latest changes from git..."
    cd "$APP_DIR"
    git fetch origin
    git reset --hard origin/$GIT_BRANCH
    git clean -fd
    log_info "Code updated from branch: $GIT_BRANCH"
else
    log_step "Cloning repository..."
    mkdir -p "$APP_DIR"
    git clone -b "$GIT_BRANCH" "$GIT_REPO" "$APP_DIR"
    cd "$APP_DIR"
    log_info "Repository cloned"
fi

# Show current commit
CURRENT_COMMIT=$(git rev-parse --short HEAD)
CURRENT_MESSAGE=$(git log -1 --pretty=%B)
log_info "Deploying commit: $CURRENT_COMMIT"
log_info "Commit message: $CURRENT_MESSAGE"

# Backend deployment
if [ -d "$APP_DIR/backend" ]; then
    log_step "Deploying backend..."
    cd "$APP_DIR/backend"
    
    # Create virtual environment if not exists
    if [ ! -d "$VENV_PATH" ]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv "$VENV_PATH"
    fi
    
    # Activate virtual environment and install dependencies
    source "$VENV_PATH/bin/activate"
    log_info "Installing Python dependencies..."
    pip install --upgrade pip
    pip install -r requirements.txt
    deactivate
    
    log_info "Backend deployment completed"
fi

# Frontend deployment
if [ -d "$APP_DIR/frontend" ]; then
    log_step "Deploying frontend..."
    cd "$APP_DIR/frontend"
    
    # Install dependencies
    log_info "Installing Node.js dependencies..."
    yarn install --frozen-lockfile
    
    # Optional: Build for production (uncomment if needed)
    # log_info "Building frontend for production..."
    # yarn build
    
    log_info "Frontend deployment completed"
fi

# Check for .env files
log_step "Checking environment configuration..."
if [ ! -f "$APP_DIR/backend/.env" ]; then
    log_warn "Backend .env file not found. Creating from template..."
    cat > "$APP_DIR/backend/.env" <<EOF
MONGO_URL="mongodb://localhost:27017"
DB_NAME="app_database"
CORS_ORIGINS="*"
EOF
fi

if [ ! -f "$APP_DIR/frontend/.env" ]; then
    log_warn "Frontend .env file not found. Creating from template..."
    cat > "$APP_DIR/frontend/.env" <<EOF
REACT_APP_BACKEND_URL=http://localhost:8001
PORT=3000
EOF
fi

# Set permissions
log_step "Setting permissions..."
chown -R appuser:appuser "$APP_DIR" 2>/dev/null || true
chmod -R 755 "$APP_DIR"

# Restart services
restart_services

# Health check
if check_health; then
    log_info "✅ Deployment completed successfully!"
    echo ""
    echo "================================================"
    echo "Deployment Summary"
    echo "================================================"
    echo "Commit: $CURRENT_COMMIT"
    echo "Branch: $GIT_BRANCH"
    echo "Backend: http://localhost:8001/api/"
    echo "Frontend: http://localhost:3000"
    echo "Nginx Proxy: http://localhost"
    echo "================================================"
else
    log_error "Health checks failed. Rolling back..."
    rollback
fi

# Display logs location
echo ""
log_info "Logs location:"
echo "  Backend:  /var/log/supervisor/backend.*.log"
echo "  Frontend: /var/log/supervisor/frontend.*.log"
echo ""
echo "To view logs in real-time:"
echo "  tail -f /var/log/supervisor/backend.out.log"
echo "  tail -f /var/log/supervisor/frontend.out.log"
