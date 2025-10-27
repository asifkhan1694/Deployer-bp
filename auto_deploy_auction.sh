#!/bin/bash
################################################################################
# BALLYPATRICK AUCTIONS DEPLOYMENT SCRIPT
# Specialized deployer for Emergent Auction Platform
# Tech Stack: React 18 + FastAPI + MongoDB + i18next + AI Translation
# 
# Usage: sudo bash auto_deploy_auction.sh
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
TOTAL_STEPS=12
CURRENT_STEP=0

################################################################################
# HELPER FUNCTIONS
################################################################################

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║       🏇 BALLYPATRICK AUCTIONS AUTO DEPLOYER 🏇              ║"
    echo "║                                                                ║"
    echo "║        Full-Stack Auction Platform Deployment                  ║"
    echo "║        React + FastAPI + MongoDB + AI Translation              ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

progress_bar() {
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

generate_jwt_secret() {
    openssl rand -hex 32
}

################################################################################
# PRE-FLIGHT CHECKS
################################################################################

print_banner

echo -e "${YELLOW}${BOLD}"
echo "Welcome! This installer will set up your Ballypatrick Auctions platform"
echo "with all required features:"
echo -e "${NC}"
echo ""
echo -e "${CYAN}Features included:${NC}"
echo "  ✓ React 18 with multi-language support (8 languages)"
echo "  ✓ FastAPI backend with JWT authentication"
echo "  ✓ MongoDB database with comprehensive schemas"
echo "  ✓ AI-powered translation (OpenAI/Anthropic)"
echo "  ✓ Admin CMS with drag & drop page builder"
echo "  ✓ File upload system"
echo "  ✓ Collections & Lots management"
echo "  ✓ Blog/News system"
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
echo "Let's gather some information about your deployment..."
echo ""

# 1. GitHub Repository
ask_question "What is your GitHub repository URL?" "" "GIT_REPO"
ask_question "Which branch should I deploy?" "main" "GIT_BRANCH"

# 2. Database name
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Database Configuration${NC}"
echo ""
ask_question "What should I name your database?" "ballypatrick_auctions" "DB_NAME"

# 3. Admin credentials
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Admin Account Setup${NC}"
echo ""
print_info "I'll create an admin account for you to manage the platform"
ask_question "Admin email" "admin@ballypatrick.com" "ADMIN_EMAIL"
ask_question "Admin username" "admin" "ADMIN_USERNAME"
ask_question "Admin password" "ChangeMe123!" "ADMIN_PASSWORD"

# 4. AI Translation (Optional)
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}AI Translation Setup (Optional)${NC}"
echo ""
print_info "For multi-language support, you can provide AI API keys"
print_info "You can skip this and add them later in the .env file"
echo ""

OPENAI_KEY=""
ANTHROPIC_KEY=""

if ask_yes_no "Do you have an OpenAI API key for translation?" "N"; then
    ask_question "OpenAI API key" "" "OPENAI_KEY"
fi

if ask_yes_no "Do you have an Anthropic API key for translation?" "N"; then
    ask_question "Anthropic API key" "" "ANTHROPIC_KEY"
fi

# 5. Seed demo data
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Demo Data${NC}"
echo ""
if ask_yes_no "Would you like me to load demo collections and lots?" "Y"; then
    SEED_DEMO_DATA=true
else
    SEED_DEMO_DATA=false
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
echo -e "  ${BOLD}Database:${NC}        $DB_NAME"
echo -e "  ${BOLD}Admin User:${NC}      $ADMIN_USERNAME ($ADMIN_EMAIL)"
echo -e "  ${BOLD}OpenAI API:${NC}      ${OPENAI_KEY:+Configured}"
echo -e "  ${BOLD}Anthropic API:${NC}   ${ANTHROPIC_KEY:+Configured}"
echo -e "  ${BOLD}Demo Data:${NC}       $( [ "$SEED_DEMO_DATA" = true ] && echo "Yes" || echo "No" )"
echo -e "  ${BOLD}Server IP:${NC}       $SERVER_IP"
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
LOG_FILE="/var/log/auto_deploy_auction_$(date +%Y%m%d_%H%M%S).log"
echo "Log file: $LOG_FILE" > $LOG_FILE

print_banner

################################################################################
CURRENT_STEP=1
print_step "Updating System Packages"
progress_bar

print_info "Checking for package manager locks..."
killall apt apt-get 2>/dev/null || true
sleep 1
rm -f /var/lib/apt/lists/lock 2>/dev/null || true
rm -f /var/cache/apt/archives/lock 2>/dev/null || true
rm -f /var/lib/dpkg/lock* 2>/dev/null || true
dpkg --configure -a 2>&1 | head -5

print_info "Updating package lists..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >> $LOG_FILE 2>&1

print_success "System packages updated"

################################################################################
CURRENT_STEP=2
print_step "Installing Python 3.11"
progress_bar

if ! command -v python3.11 &> /dev/null; then
    print_info "Installing Python 3.11..."
    apt-get install -y software-properties-common >> $LOG_FILE 2>&1
    add-apt-repository -y ppa:deadsnakes/ppa >> $LOG_FILE 2>&1
    apt-get update -qq >> $LOG_FILE 2>&1
    apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip >> $LOG_FILE 2>&1
    print_success "Python 3.11 installed"
else
    print_success "Python 3.11 already installed"
fi

# Make python3.11 default
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 >> $LOG_FILE 2>&1 || true
update-alternatives --set python3 /usr/bin/python3.11 >> $LOG_FILE 2>&1 || true

python3 --version

################################################################################
CURRENT_STEP=3
print_step "Installing Node.js 20.x"
progress_bar

if ! command -v node &> /dev/null || ! node --version | grep -q "v20"; then
    print_info "Installing Node.js 20.x..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >> $LOG_FILE 2>&1
    apt-get install -y nodejs >> $LOG_FILE 2>&1
    print_success "Node.js 20.x installed"
else
    print_success "Node.js 20.x already installed"
fi

node --version

# Install Yarn globally
if ! command -v yarn &> /dev/null; then
    print_info "Installing Yarn package manager..."
    npm install -g yarn >> $LOG_FILE 2>&1
    print_success "Yarn installed"
else
    print_success "Yarn already installed"
fi

yarn --version

################################################################################
CURRENT_STEP=4
print_step "Installing MongoDB 7.x"
progress_bar

if ! command -v mongod &> /dev/null; then
    print_info "Installing MongoDB 7.x..."
    
    # Import MongoDB public key
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg >> $LOG_FILE 2>&1
    
    # Add MongoDB repository
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list >> $LOG_FILE 2>&1
    
    apt-get update -qq >> $LOG_FILE 2>&1
    apt-get install -y mongodb-org >> $LOG_FILE 2>&1
    
    # Create data directory
    mkdir -p /data/db
    chown -R mongodb:mongodb /data/db
    
    print_success "MongoDB 7.x installed"
else
    print_success "MongoDB already installed"
fi

# Start MongoDB
systemctl start mongod >> $LOG_FILE 2>&1 || true
systemctl enable mongod >> $LOG_FILE 2>&1 || true

print_success "MongoDB is running"

################################################################################
CURRENT_STEP=5
print_step "Installing Supervisor"
progress_bar

if ! command -v supervisorctl &> /dev/null; then
    print_info "Installing Supervisor..."
    apt-get install -y supervisor >> $LOG_FILE 2>&1
    systemctl enable supervisor >> $LOG_FILE 2>&1
    systemctl start supervisor >> $LOG_FILE 2>&1
    print_success "Supervisor installed"
else
    print_success "Supervisor already installed"
fi

################################################################################
CURRENT_STEP=6
print_step "Cloning Application Code"
progress_bar

APP_DIR="/app"

if [ -d "$APP_DIR" ]; then
    print_info "Application directory exists, backing up..."
    mv $APP_DIR ${APP_DIR}_backup_$(date +%Y%m%d_%H%M%S)
fi

print_info "Cloning from $GIT_REPO (branch: $GIT_BRANCH)..."
git clone -b $GIT_BRANCH $GIT_REPO $APP_DIR >> $LOG_FILE 2>&1

print_success "Application code cloned"

################################################################################
CURRENT_STEP=7
print_step "Setting Up Backend"
progress_bar

cd $APP_DIR/backend

# Generate JWT secret
JWT_SECRET=$(generate_jwt_secret)

# Create .env file
print_info "Creating backend environment configuration..."
cat > .env << EOF
MONGO_URL=mongodb://localhost:27017
DB_NAME=$DB_NAME
JWT_SECRET=$JWT_SECRET
JWT_ALGORITHM=HS256
CORS_ORIGINS=*
EOF

# Add API keys if provided
if [ -n "$OPENAI_KEY" ]; then
    echo "OPENAI_API_KEY=$OPENAI_KEY" >> .env
    print_success "OpenAI API key configured"
fi

if [ -n "$ANTHROPIC_KEY" ]; then
    echo "ANTHROPIC_API_KEY=$ANTHROPIC_KEY" >> .env
    print_success "Anthropic API key configured"
fi

# Install Python dependencies
print_info "Installing Python dependencies..."
pip3 install -r requirements.txt >> $LOG_FILE 2>&1

# Create uploads directory
print_info "Creating uploads directory..."
mkdir -p uploads
chmod 755 uploads

print_success "Backend setup complete"

################################################################################
CURRENT_STEP=8
print_step "Setting Up Frontend"
progress_bar

cd $APP_DIR/frontend

# Detect backend URL (use environment variable or default)
BACKEND_URL=${REACT_APP_BACKEND_URL:-"http://localhost:8001"}

# Create .env file
print_info "Creating frontend environment configuration..."
cat > .env << EOF
REACT_APP_BACKEND_URL=$BACKEND_URL
EOF

# Install dependencies with Yarn
print_info "Installing frontend dependencies (this may take a few minutes)..."
yarn install >> $LOG_FILE 2>&1

print_success "Frontend setup complete"

################################################################################
CURRENT_STEP=9
print_step "Configuring Supervisor"
progress_bar

print_info "Creating supervisor configuration..."

# Backend supervisor config
cat > /etc/supervisor/conf.d/auction-backend.conf << EOF
[program:auction-backend]
command=python3 -m uvicorn server:app --host 0.0.0.0 --port 8001
directory=$APP_DIR/backend
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/auction-backend.err.log
stdout_logfile=/var/log/supervisor/auction-backend.out.log
environment=PYTHONUNBUFFERED="1"
EOF

# Frontend supervisor config
cat > /etc/supervisor/conf.d/auction-frontend.conf << EOF
[program:auction-frontend]
command=yarn start
directory=$APP_DIR/frontend
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/auction-frontend.err.log
stdout_logfile=/var/log/supervisor/auction-frontend.out.log
environment=PORT="3000",NODE_ENV="production"
EOF

# Reload supervisor
supervisorctl reread >> $LOG_FILE 2>&1
supervisorctl update >> $LOG_FILE 2>&1

print_success "Supervisor configured"

################################################################################
CURRENT_STEP=10
print_step "Seeding Database"
progress_bar

cd $APP_DIR/backend

# Create admin user seed script with provided credentials
print_info "Creating admin user seed script..."
cat > seed_admin_custom.py << EOF
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from passlib.context import CryptContext
import os
from dotenv import load_dotenv
from datetime import datetime, timezone
import uuid

load_dotenv()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

async def seed_admin():
    client = AsyncIOMotorClient(os.environ['MONGO_URL'])
    db = client[os.environ['DB_NAME']]
    
    # Check if admin exists
    existing = await db.users.find_one({"email": "$ADMIN_EMAIL"})
    if existing:
        print("Admin user already exists")
        return
    
    # Create admin user
    admin_user = {
        "id": str(uuid.uuid4()),
        "email": "$ADMIN_EMAIL",
        "username": "$ADMIN_USERNAME",
        "password_hash": pwd_context.hash("$ADMIN_PASSWORD"),
        "role": "admin",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat()
    }
    
    await db.users.insert_one(admin_user)
    print("Admin user created successfully")
    print(f"Email: $ADMIN_EMAIL")
    print(f"Username: $ADMIN_USERNAME")
    print(f"Password: $ADMIN_PASSWORD")
    
    client.close()

if __name__ == "__main__":
    asyncio.run(seed_admin())
EOF

# Run seed scripts
print_info "Creating admin user..."
python3 seed_admin_custom.py >> $LOG_FILE 2>&1

# Check if other seed scripts exist and run them
if [ -f "seed_menu.py" ]; then
    print_info "Seeding menu items..."
    python3 seed_menu.py >> $LOG_FILE 2>&1
fi

if [ -f "seed_pages.py" ]; then
    print_info "Seeding pages..."
    python3 seed_pages.py >> $LOG_FILE 2>&1
fi

if [ "$SEED_DEMO_DATA" = true ]; then
    if [ -f "seed_collections_lots.py" ]; then
        print_info "Seeding demo collections and lots..."
        python3 seed_collections_lots.py >> $LOG_FILE 2>&1
    fi
fi

print_success "Database seeded successfully"

################################################################################
CURRENT_STEP=11
print_step "Starting Services"
progress_bar

print_info "Starting backend service..."
supervisorctl start auction-backend >> $LOG_FILE 2>&1

print_info "Starting frontend service..."
supervisorctl start auction-frontend >> $LOG_FILE 2>&1

# Wait for services to start
print_info "Waiting for services to initialize (30 seconds)..."
sleep 30

# Check if services are running
if supervisorctl status auction-backend | grep -q "RUNNING"; then
    print_success "Backend service is running"
else
    print_warning "Backend service may not be running properly"
fi

if supervisorctl status auction-frontend | grep -q "RUNNING"; then
    print_success "Frontend service is running"
else
    print_warning "Frontend service may not be running properly"
fi

################################################################################
CURRENT_STEP=12
print_step "Final Health Checks"
progress_bar

print_info "Testing backend API..."
if curl -s http://localhost:8001/api/ > /dev/null 2>&1; then
    print_success "Backend API is responding"
else
    print_warning "Backend API is not responding yet (may need more time)"
fi

print_info "Testing frontend..."
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    print_success "Frontend is responding"
else
    print_warning "Frontend is not responding yet (may need more time)"
fi

################################################################################
# SUCCESS MESSAGE
################################################################################

print_banner

echo -e "${GREEN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║                   🎉 SUCCESS! 🎉                              ║"
echo "║                                                                ║"
echo "║     Your Ballypatrick Auctions Platform is now LIVE!         ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}📱 Access Your Application:${NC}"
echo ""
echo -e "  🌐 ${BOLD}Application:${NC}    http://$SERVER_IP"
echo -e "  📡 ${BOLD}API Docs:${NC}       http://$SERVER_IP:8001/docs"
echo -e "  🔧 ${BOLD}Backend API:${NC}    http://$SERVER_IP:8001/api/"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}🔐 Admin Credentials:${NC}"
echo ""
echo -e "  📧 ${BOLD}Email:${NC}          $ADMIN_EMAIL"
echo -e "  👤 ${BOLD}Username:${NC}       $ADMIN_USERNAME"
echo -e "  🔑 ${BOLD}Password:${NC}       $ADMIN_PASSWORD"
echo ""
echo -e "${YELLOW}⚠️  Please change the admin password after first login!${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}📂 Important Paths:${NC}"
echo ""
echo -e "  🗂️  ${BOLD}Application:${NC}    $APP_DIR"
echo -e "  📝 ${BOLD}Backend .env:${NC}   $APP_DIR/backend/.env"
echo -e "  📝 ${BOLD}Frontend .env:${NC}  $APP_DIR/frontend/.env"
echo -e "  📊 ${BOLD}Logs:${NC}           /var/log/supervisor/"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}🛠️  Useful Commands:${NC}"
echo ""
echo -e "  ${CYAN}# Check service status${NC}"
echo -e "  sudo supervisorctl status"
echo ""
echo -e "  ${CYAN}# Restart services${NC}"
echo -e "  sudo supervisorctl restart auction-backend"
echo -e "  sudo supervisorctl restart auction-frontend"
echo -e "  sudo supervisorctl restart all"
echo ""
echo -e "  ${CYAN}# View logs${NC}"
echo -e "  tail -f /var/log/supervisor/auction-backend.err.log"
echo -e "  tail -f /var/log/supervisor/auction-frontend.err.log"
echo ""
echo -e "  ${CYAN}# Update application${NC}"
echo -e "  cd $APP_DIR"
echo -e "  git pull"
echo -e "  sudo supervisorctl restart all"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}✨ Features Available:${NC}"
echo ""
echo -e "  ✓ Multi-language support (8 languages)"
echo -e "  ✓ AI-powered translation"
echo -e "  ✓ Admin CMS with page builder"
echo -e "  ✓ Collections & lots management"
echo -e "  ✓ Blog/news system"
echo -e "  ✓ File upload system"
echo -e "  ✓ JWT authentication"
echo ""
echo -e "${GREEN}${BOLD}🎉 Happy Auctioneering! 🎉${NC}"
echo ""
