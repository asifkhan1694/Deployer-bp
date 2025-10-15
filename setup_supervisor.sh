#!/bin/bash
# Setup Supervisor configuration for FastAPI + React Application

set -e

# Configuration
APP_DIR="${APP_DIR:-/opt/app}"
VENV_PATH="${VENV_PATH:-$APP_DIR/venv}"
APP_USER="${APP_USER:-appuser}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "================================================"
echo "Supervisor Configuration Setup"
echo "================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Check if app directory exists
if [ ! -d "$APP_DIR" ]; then
    log_error "Application directory not found: $APP_DIR"
    exit 1
fi

# Create Supervisor configuration
log_info "Creating Supervisor configuration..."

cat > /etc/supervisor/conf.d/app.conf <<EOF
[program:backend]
command=$VENV_PATH/bin/uvicorn server:app --host 0.0.0.0 --port 8001 --workers 1 --reload
directory=$APP_DIR/backend
user=$APP_USER
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/backend.err.log
stdout_logfile=/var/log/supervisor/backend.out.log
stopsignal=TERM
stopwaitsecs=30
stopasgroup=true
killasgroup=true
environment=PATH="$VENV_PATH/bin:%(ENV_PATH)s"

[program:frontend]
command=yarn start
directory=$APP_DIR/frontend
user=$APP_USER
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/frontend.err.log
stdout_logfile=/var/log/supervisor/frontend.out.log
stopsignal=TERM
stopwaitsecs=50
stopasgroup=true
killasgroup=true
environment=HOST="0.0.0.0",PORT="3000"

[group:app]
programs=backend,frontend
priority=999
EOF

log_info "Supervisor configuration created at: /etc/supervisor/conf.d/app.conf"

# Create log directory if not exists
mkdir -p /var/log/supervisor
chown -R $APP_USER:$APP_USER /var/log/supervisor 2>/dev/null || true

# Reload Supervisor
log_info "Reloading Supervisor..."
supervisorctl reread
supervisorctl update

# Start services
log_info "Starting services..."
supervisorctl start app:*

# Check status
log_info "Service status:"
supervisorctl status

echo ""
log_info "✅ Supervisor setup completed!"
echo ""
echo "Useful commands:"
echo "  supervisorctl status              # Check status"
echo "  supervisorctl restart app:*       # Restart all services"
echo "  supervisorctl restart backend     # Restart backend only"
echo "  supervisorctl restart frontend    # Restart frontend only"
echo "  supervisorctl tail -f backend     # View backend logs"
echo "  supervisorctl tail -f frontend    # View frontend logs"
