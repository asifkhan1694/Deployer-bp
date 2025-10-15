#!/bin/bash
# Ubuntu 22.04 FastAPI + React Application Installer
# This script installs all dependencies needed for the application

set -e  # Exit on error

echo "================================================"
echo "FastAPI + React Application Installer"
echo "Ubuntu 22.04 LTS"
echo "================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Update system packages
log_info "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install essential build tools
log_info "Installing essential build tools..."
apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    supervisor \
    nginx

# Install Python 3.11
log_info "Installing Python 3.11..."
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update
apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip

# Create symlink for python3 to python3.11
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Install Node.js 20.x
log_info "Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Yarn
log_info "Installing Yarn..."
npm install -g yarn

# Install MongoDB
log_info "Installing MongoDB..."
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
    gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-7.0.list

apt-get update
apt-get install -y mongodb-org

# Enable and start MongoDB
systemctl enable mongod
systemctl start mongod

# Verify MongoDB is running
if systemctl is-active --quiet mongod; then
    log_info "MongoDB is running successfully"
else
    log_error "MongoDB failed to start"
    exit 1
fi

# Install PM2 (alternative process manager)
log_info "Installing PM2..."
npm install -g pm2

# Create application directory
log_info "Creating application directory..."
mkdir -p /opt/app
mkdir -p /var/log/app

# Create application user (non-root)
log_info "Creating application user..."
if ! id "appuser" &>/dev/null; then
    useradd -r -m -s /bin/bash appuser
    usermod -aG sudo appuser
fi

# Set up firewall (UFW)
log_info "Configuring firewall..."
ufw --force enable
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3000/tcp  # Frontend (optional, can be removed in production)
ufw allow 8001/tcp  # Backend API (optional, can be removed in production)
ufw reload

# Configure Nginx as reverse proxy
log_info "Configuring Nginx..."
cat > /etc/nginx/sites-available/app <<'EOF'
server {
    listen 80;
    server_name _;

    # Frontend
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8001/api/;
        proxy_http_version 1.1;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Restart Nginx
systemctl restart nginx
systemctl enable nginx

# Print versions
log_info "Installation Summary:"
echo "----------------------------------------"
echo "Python: $(python3 --version)"
echo "Node.js: $(node --version)"
echo "NPM: $(npm --version)"
echo "Yarn: $(yarn --version)"
echo "MongoDB: $(mongod --version | head -n 1)"
echo "Supervisor: $(supervisord --version)"
echo "Nginx: $(nginx -v 2>&1)"
echo "----------------------------------------"

log_info "Installation completed successfully!"
echo ""
echo "Next steps:"
echo "1. Clone your git repository to /opt/app"
echo "2. Configure environment variables"
echo "3. Run ./setup_supervisor.sh to configure process management"
echo "4. Run ./deploy.sh to deploy the application"
echo ""
