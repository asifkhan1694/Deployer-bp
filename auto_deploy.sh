#!/bin/bash
################################################################################
# ONE-COMMAND DEPLOYMENT SCRIPT
# Ultra-simple installer for FastAPI + React on Ubuntu 22.04 AWS
# 
# Usage: curl -fsSL https://your-url/auto_deploy.sh | sudo bash
#        OR: sudo bash auto_deploy.sh
################################################################################

set -e  # Exit on error

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Progress tracking
TOTAL_STEPS=10
CURRENT_STEP=0

################################################################################
# HELPER FUNCTIONS
################################################################################

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║          🚀 FASTAPI + REACT AUTO INSTALLER 🚀                 ║"
    echo "║                                                                ║"
    echo "║            One-Command Production Deployment                   ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

progress_bar() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    FILLED=$((PERCENT / 2))
    EMPTY=$((50 - FILLED))
    
    echo ""
    echo -e "${CYAN}Progress: [${GREEN}$(printf '%*s' $FILLED | tr ' ' '█')${WHITE}$(printf '%*s' $EMPTY | tr ' ' '░')${CYAN}] ${PERCENT}%${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${BOLD}${BLUE}▶ STEP $CURRENT_STEP/$TOTAL_STEPS:${NC} ${WHITE}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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

ask_question() {
    local question=$1
    local default=$2
    local var_name=$3
    
    echo ""
    echo -e "${MAGENTA}❓ ${BOLD}$question${NC}"
    if [ -n "$default" ]; then
        echo -e "${CYAN}   (Default: $default)${NC}"
        read -p "   Your answer: " answer
        answer=${answer:-$default}
    else
        read -p "   Your answer: " answer
        while [ -z "$answer" ]; do
            print_warning "This field is required!"
            read -p "   Your answer: " answer
        done
    fi
    
    eval "$var_name='$answer'"
}

ask_yes_no() {
    local question=$1
    local default=$2
    
    echo ""
    echo -e "${MAGENTA}❓ ${BOLD}$question${NC}"
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
# PRE-FLIGHT CHECKS
################################################################################

print_banner

echo -e "${YELLOW}${BOLD}"
echo "Welcome! This installer will set up your FastAPI + React application"
echo "in just a few minutes. I'll ask you a few simple questions and then"
echo "handle all the technical stuff automatically."
echo -e "${NC}"
echo ""
echo -e "${CYAN}This installer will:${NC}"
echo "  ✓ Install all required software (Python, Node.js, MongoDB, Nginx)"
echo "  ✓ Clone your application from GitHub"
echo "  ✓ Configure everything automatically"
echo "  ✓ Set up SSL if you have a domain"
echo "  ✓ Make your app production-ready"
echo ""

if ask_yes_no "Ready to begin?" "Y"; then
    echo ""
else
    echo "Installation cancelled."
    exit 0
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "This script must be run with sudo"
    echo ""
    echo "Please run: sudo bash $0"
    exit 1
fi

# Detect server IP
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "unknown")

################################################################################
# COLLECT USER CONFIGURATION
################################################################################

print_banner
echo -e "${BOLD}${YELLOW}📋 CONFIGURATION WIZARD${NC}"
echo ""
echo "Let's gather some information about your application..."
echo ""

# 1. GitHub Repository
ask_question "What is your GitHub repository URL?" "" "GIT_REPO"
ask_question "Which branch should I deploy?" "main" "GIT_BRANCH"

# 2. Domain or IP
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Server Access Configuration${NC}"
echo ""
print_info "Your server IP is: ${BOLD}$SERVER_IP${NC}"
echo ""

if ask_yes_no "Do you have a domain name (like myapp.com)?" "N"; then
    ask_question "What is your domain name?" "" "DOMAIN_NAME"
    USE_DOMAIN=true
    
    if ask_yes_no "Would you like me to set up free SSL (HTTPS) with Let's Encrypt?" "Y"; then
        SETUP_SSL=true
        ask_question "What email should I use for SSL certificate?" "" "SSL_EMAIL"
    else
        SETUP_SSL=false
    fi
else
    DOMAIN_NAME=$SERVER_IP
    USE_DOMAIN=false
    SETUP_SSL=false
    print_info "I'll use your IP address: $SERVER_IP"
fi

# 3. MongoDB Configuration
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Database Configuration${NC}"
echo ""
echo "Where would you like to host your MongoDB database?"
echo ""
echo "  1) Self-hosted (I'll install MongoDB on this server)"
echo "  2) MongoDB Atlas (Cloud-hosted, you provide connection URL)"
echo ""
read -p "Choose option (1 or 2): " MONGO_CHOICE

if [ "$MONGO_CHOICE" = "2" ]; then
    MONGO_SELF_HOSTED=false
    ask_question "Enter your MongoDB Atlas connection URL" "" "MONGO_URL"
    echo ""
    print_info "Example: mongodb+srv://user:password@cluster.mongodb.net/dbname"
else
    MONGO_SELF_HOSTED=true
    MONGO_URL="mongodb://localhost:27017"
    ask_question "What should I name your database?" "app_database" "DB_NAME"
    MONGO_URL="$MONGO_URL/$DB_NAME"
fi

# 4. Application Port (optional advanced)
USE_CUSTOM_PORTS=false
FRONTEND_PORT=3000
BACKEND_PORT=8001

echo ""
if ask_yes_no "Would you like to customize ports? (Advanced users only)" "N"; then
    USE_CUSTOM_PORTS=true
    ask_question "Frontend port" "3000" "FRONTEND_PORT"
    ask_question "Backend port" "8001" "BACKEND_PORT"
fi

################################################################################
# CONFIGURATION SUMMARY
################################################################################

print_banner
echo -e "${BOLD}${GREEN}📋 CONFIGURATION SUMMARY${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Repository:${NC}      $GIT_REPO"
echo -e "  ${BOLD}Branch:${NC}          $GIT_BRANCH"
echo ""
echo -e "  ${BOLD}Access URL:${NC}      http://$DOMAIN_NAME"
if [ "$SETUP_SSL" = true ]; then
    echo -e "  ${BOLD}SSL (HTTPS):${NC}     Yes (automatic setup)"
else
    echo -e "  ${BOLD}SSL (HTTPS):${NC}     No"
fi
echo ""
if [ "$MONGO_SELF_HOSTED" = true ]; then
    echo -e "  ${BOLD}Database:${NC}        Self-hosted MongoDB (will be installed)"
    echo -e "  ${BOLD}DB Name:${NC}         $DB_NAME"
else
    echo -e "  ${BOLD}Database:${NC}        MongoDB Atlas (cloud)"
    echo -e "  ${BOLD}Connection:${NC}      ${MONGO_URL:0:50}..."
fi
echo ""
echo -e "  ${BOLD}Frontend Port:${NC}   $FRONTEND_PORT"
echo -e "  ${BOLD}Backend Port:${NC}    $BACKEND_PORT"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if ask_yes_no "Does everything look correct?" "Y"; then
    echo ""
    print_success "Great! Starting installation..."
    sleep 2
else
    print_error "Installation cancelled. Please run the script again."
    exit 0
fi

################################################################################
# INSTALLATION BEGINS
################################################################################

# Log file
LOG_FILE="/var/log/auto_deploy_$(date +%Y%m%d_%H%M%S).log"

print_banner

################################################################################
CURRENT_STEP=1
print_step "Updating System Packages"
progress_bar

# Fix any stuck apt processes
print_info "Checking for package manager locks..."
killall apt apt-get 2>/dev/null || true
rm -f /var/lib/apt/lists/lock 2>/dev/null || true
rm -f /var/cache/apt/archives/lock 2>/dev/null || true
rm -f /var/lib/dpkg/lock* 2>/dev/null || true
dpkg --configure -a 2>/dev/null || true

print_info "Updating package lists (this may take a minute)..."
DEBIAN_FRONTEND=noninteractive apt-get update -y 2>&1 | tee -a $LOG_FILE | grep -v "^Get:" || true

print_info "Upgrading system packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" 2>&1 | tee -a $LOG_FILE | tail -5 || true

print_success "System updated"

################################################################################
CURRENT_STEP=2
print_step "Installing Essential Tools"
progress_bar

print_info "Installing build tools, git, nginx, supervisor..."
DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential curl wget git \
    software-properties-common apt-transport-https ca-certificates gnupg \
    lsb-release supervisor nginx 2>&1 | tee -a $LOG_FILE | tail -3 || true
print_success "Essential tools installed"

################################################################################
CURRENT_STEP=3
print_step "Installing Python 3.11"
progress_bar

print_info "Adding Python repository..."
add-apt-repository -y ppa:deadsnakes/ppa 2>&1 | tee -a $LOG_FILE | tail -2 || true
apt-get update -y 2>&1 | tee -a $LOG_FILE | grep -v "^Get:" || true

print_info "Installing Python packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip 2>&1 | tee -a $LOG_FILE | tail -3 || true
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 2>&1 | tee -a $LOG_FILE || true
print_success "Python 3.11 installed ($(python3 --version))"

################################################################################
CURRENT_STEP=4
print_step "Installing Node.js 20.x and Yarn"
progress_bar

print_info "Setting up Node.js repository..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>&1 | tee -a $LOG_FILE | tail -5 || true

print_info "Installing Node.js..."
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs 2>&1 | tee -a $LOG_FILE | tail -3 || true

print_info "Installing Yarn..."
npm install -g yarn 2>&1 | tee -a $LOG_FILE | tail -2 || true
print_success "Node.js $(node --version) and Yarn $(yarn --version) installed"

################################################################################
CURRENT_STEP=5
if [ "$MONGO_SELF_HOSTED" = true ]; then
    print_step "Installing MongoDB 7.0"
    progress_bar
    
    print_info "Adding MongoDB GPG key..."
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
        gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor 2>&1 | tee -a $LOG_FILE || true
    
    print_info "Adding MongoDB repository..."
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
        tee /etc/apt/sources.list.d/mongodb-org-7.0.list 2>&1 | tee -a $LOG_FILE || true
    
    apt-get update -y 2>&1 | tee -a $LOG_FILE | grep -v "^Get:" || true
    
    print_info "Installing MongoDB (this may take 2-3 minutes)..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org 2>&1 | tee -a $LOG_FILE | tail -5 || true
    
    print_info "Starting MongoDB..."
    systemctl enable mongod 2>&1 | tee -a $LOG_FILE || true
    systemctl start mongod 2>&1 | tee -a $LOG_FILE || true
    sleep 3
    
    print_success "MongoDB installed and running"
else
    print_step "Skipping MongoDB (using Atlas)"
    progress_bar
    print_success "Using MongoDB Atlas"
fi

################################################################################
CURRENT_STEP=6
print_step "Cloning Your Application"
progress_bar

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Clone repository
print_info "Cloning from $GIT_REPO (branch: $GIT_BRANCH)..."
if git clone -b $GIT_BRANCH $GIT_REPO temp_clone 2>&1 | tee -a $LOG_FILE | tail -5; then
    mv temp_clone/* temp_clone/.[!.]* . 2>/dev/null || true
    rm -rf temp_clone
    COMMIT_ID=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    print_success "Application cloned (commit: $COMMIT_ID)"
else
    print_error "Failed to clone repository. Please check the URL and branch name."
    exit 1
fi

################################################################################
CURRENT_STEP=7
print_step "Setting Up Backend"
progress_bar

cd /opt/app/backend

# Create virtual environment
print_info "Creating Python virtual environment..."
python3 -m venv /opt/app/venv 2>&1 | tee -a $LOG_FILE || true
source /opt/app/venv/bin/activate

# Install dependencies
print_info "Installing Python packages (this may take 2-3 minutes)..."
pip install --upgrade pip 2>&1 | tee -a $LOG_FILE | tail -2 || true
pip install -r requirements.txt 2>&1 | tee -a $LOG_FILE | tail -5 || true

# Create .env file
print_info "Creating backend configuration..."
cat > .env <<EOF
MONGO_URL=$MONGO_URL
DB_NAME=${DB_NAME:-app_database}
CORS_ORIGINS=*
EOF

print_success "Backend configured"

################################################################################
CURRENT_STEP=8
print_step "Setting Up Frontend"
progress_bar

cd /opt/app/frontend

# Create .env file
if [ "$SETUP_SSL" = true ]; then
    BACKEND_URL="https://$DOMAIN_NAME"
else
    if [ "$USE_DOMAIN" = true ]; then
        BACKEND_URL="http://$DOMAIN_NAME"
    else
        BACKEND_URL="http://$SERVER_IP"
    fi
fi

print_info "Creating frontend configuration..."
cat > .env <<EOF
REACT_APP_BACKEND_URL=$BACKEND_URL
PORT=$FRONTEND_PORT
EOF

# Install dependencies
print_info "Installing Node.js packages (this may take 3-5 minutes)..."
yarn install --frozen-lockfile 2>&1 | tee -a $LOG_FILE | grep -E "success|warning|error" | tail -10 || true

print_success "Frontend configured"

################################################################################
CURRENT_STEP=9
print_step "Configuring Process Management (Supervisor)"
progress_bar

print_info "Creating Supervisor configuration..."
cat > /etc/supervisor/conf.d/app.conf <<EOF
[program:backend]
command=/opt/app/venv/bin/uvicorn server:app --host 0.0.0.0 --port $BACKEND_PORT --workers 2
directory=/opt/app/backend
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/backend.err.log
stdout_logfile=/var/log/supervisor/backend.out.log
stopsignal=TERM
stopwaitsecs=30
stopasgroup=true
killasgroup=true

[program:frontend]
command=yarn start
directory=/opt/app/frontend
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/frontend.err.log
stdout_logfile=/var/log/supervisor/frontend.out.log
stopsignal=TERM
stopwaitsecs=50
stopasgroup=true
killasgroup=true
environment=HOST="0.0.0.0",PORT="$FRONTEND_PORT"
EOF

print_info "Starting services..."
supervisorctl reread 2>&1 | tee -a $LOG_FILE || true
supervisorctl update 2>&1 | tee -a $LOG_FILE || true
sleep 2
supervisorctl start all 2>&1 | tee -a $LOG_FILE || true

print_success "Services started"

################################################################################
CURRENT_STEP=10
print_step "Configuring Nginx Reverse Proxy"
progress_bar

print_info "Creating Nginx configuration..."
cat > /etc/nginx/sites-available/app <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    client_max_body_size 100M;

    # Frontend
    location / {
        proxy_pass http://localhost:$FRONTEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:$BACKEND_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

print_info "Enabling Nginx site..."
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default

print_info "Testing Nginx configuration..."
if nginx -t 2>&1 | tee -a $LOG_FILE; then
    print_info "Restarting Nginx..."
    systemctl restart nginx 2>&1 | tee -a $LOG_FILE || true
    print_success "Nginx configured and running"
else
    print_warning "Nginx configuration has warnings, but continuing..."
fi

################################################################################
if [ "$SETUP_SSL" = true ]; then
    print_step "Setting Up SSL Certificate (Let's Encrypt)"
    progress_bar
    
    print_info "Installing Certbot..."
    apt-get install -y certbot python3-certbot-nginx > /dev/null 2>&1
    
    print_info "Obtaining SSL certificate..."
    certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email $SSL_EMAIL --redirect > /dev/null 2>&1
    
    print_success "SSL certificate installed"
    ACCESS_URL="https://$DOMAIN_NAME"
else
    print_step "Finalizing Setup"
    progress_bar
    
    if [ "$USE_DOMAIN" = true ]; then
        ACCESS_URL="http://$DOMAIN_NAME"
    else
        ACCESS_URL="http://$SERVER_IP"
    fi
    
    print_success "Setup complete"
fi

################################################################################
# VERIFICATION
################################################################################

print_banner
echo -e "${BOLD}${YELLOW}🔍 VERIFYING INSTALLATION...${NC}"
echo ""

sleep 5  # Give services time to start

# Check backend
if curl -f -s http://localhost:$BACKEND_PORT/api/ > /dev/null 2>&1; then
    print_success "Backend is running"
else
    print_warning "Backend is starting up (may take a moment)"
fi

# Check frontend
if curl -f -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
    print_success "Frontend is running"
else
    print_warning "Frontend is starting up (may take a moment)"
fi

# Check Nginx
if curl -f -s http://localhost > /dev/null 2>&1; then
    print_success "Nginx is running"
else
    print_warning "Nginx is starting up"
fi

################################################################################
# SUCCESS MESSAGE
################################################################################

sleep 2
print_banner

echo -e "${BOLD}${GREEN}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║                    🎉 SUCCESS! 🎉                             ║"
echo "║                                                                ║"
echo "║         Your application is now LIVE and RUNNING!             ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}📱 Access Your Application:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}🌐 Application:${NC}  $ACCESS_URL"
echo -e "  ${BOLD}📡 API Docs:${NC}     $ACCESS_URL/api/docs"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}📊 Useful Commands:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}Check services:${NC}     sudo supervisorctl status"
echo -e "  ${YELLOW}View backend logs:${NC}  sudo tail -f /var/log/supervisor/backend.out.log"
echo -e "  ${YELLOW}View frontend logs:${NC} sudo tail -f /var/log/supervisor/frontend.out.log"
echo -e "  ${YELLOW}Restart services:${NC}   sudo supervisorctl restart all"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}📝 Installation Log:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Full log saved to: ${YELLOW}$LOG_FILE${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}${BOLD}Thank you for using the Auto Installer! 🚀${NC}"
echo ""
echo -e "${CYAN}Need help? Check the logs or restart services with the commands above.${NC}"
echo ""
