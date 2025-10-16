#!/bin/bash
# SIMPLEST POSSIBLE INSTALLER - ZERO FILTERING

set -e

echo "======================================"
echo "SIMPLE INSTALLER - SHOWS EVERYTHING"
echo "======================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Run with sudo"
    exit 1
fi

# Config
read -p "GitHub repo URL: " GIT_REPO
read -p "Branch (default: main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}
read -p "Database (1=self, 2=atlas): " MONGO_CHOICE

if [ "$MONGO_CHOICE" = "2" ]; then
    read -p "Atlas URL: " MONGO_URL
    MONGO_SELF_HOSTED=false
else
    MONGO_SELF_HOSTED=true
    DB_NAME="app_database"
    MONGO_URL="mongodb://localhost:27017/$DB_NAME"
fi

SERVER_IP=$(curl -s ifconfig.me || echo "localhost")

echo ""
echo "Starting installation..."
echo ""
read -p "Press Enter to continue..."

# Everything below shows FULL output

echo ""
echo "========== STEP 1: FIX LOCKS =========="
killall apt apt-get 2>/dev/null || echo "No apt processes to kill"
rm -f /var/lib/dpkg/lock* 2>/dev/null || echo "No locks to remove"
dpkg --configure -a
apt-get install --reinstall python3-apt -y

echo ""
echo "========== STEP 2: UPDATE SYSTEM =========="
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

echo ""
echo "========== STEP 3: INSTALL TOOLS =========="
apt-get install -y build-essential curl wget git software-properties-common \
    apt-transport-https ca-certificates gnupg supervisor nginx

echo ""
echo "========== STEP 4: INSTALL PYTHON 3.11 =========="
apt-get install -y software-properties-common python3-launchpadlib
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update -y
apt-get install -y python3.11 python3.11-venv python3.11-dev python3-pip
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

echo ""
echo "Python version:"
python3 --version

echo ""
echo "========== STEP 5: INSTALL NODE.JS 20 =========="
echo "Removing old Node.js..."
apt-get remove -y nodejs npm 2>/dev/null || true
apt-get autoremove -y

echo "Downloading Node.js setup script..."
curl -fsSL https://deb.nodesource.com/setup_20.x -o /tmp/nodesource_setup.sh

echo "Running Node.js setup..."
bash /tmp/nodesource_setup.sh

echo "Installing Node.js..."
apt-get install -y nodejs

echo "Node version:"
node --version

echo "npm version:"
npm --version

echo "Installing Yarn..."
npm install -g yarn

echo "Yarn version:"
yarn --version

if [ "$MONGO_SELF_HOSTED" = true ]; then
    echo ""
    echo "========== STEP 6: INSTALL MONGODB =========="
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
        gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
        tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    
    apt-get update -y
    apt-get install -y mongodb-org
    
    systemctl enable mongod
    systemctl start mongod
    sleep 3
    
    echo "MongoDB status:"
    systemctl status mongod --no-pager | head -10
else
    echo ""
    echo "========== STEP 6: SKIP MONGODB (USING ATLAS) =========="
fi

echo ""
echo "========== STEP 7: CLONE APPLICATION =========="
mkdir -p /opt/app
cd /opt/app

if [ -d ".git" ]; then
    echo "Pulling latest changes..."
    git fetch origin
    git reset --hard origin/$GIT_BRANCH
else
    echo "Cloning repository..."
    git clone -b $GIT_BRANCH $GIT_REPO temp_clone
    mv temp_clone/* temp_clone/.[!.]* . 2>/dev/null || true
    rm -rf temp_clone
fi

echo "Current commit:"
git log -1 --oneline

echo ""
echo "========== STEP 8: SETUP BACKEND =========="
cd /opt/app/backend

echo "Creating Python virtual environment..."
python3 -m venv /opt/app/venv

echo "Activating venv..."
source /opt/app/venv/bin/activate

echo "Current pip:"
which pip
pip --version

# Fix requirements.txt
if grep -q "emergentintegrations" requirements.txt 2>/dev/null; then
    echo "Removing emergentintegrations from requirements.txt..."
    grep -v "emergentintegrations" requirements.txt > requirements_temp.txt
    mv requirements_temp.txt requirements.txt
    echo "Fixed!"
fi

echo "Upgrading pip..."
pip install --upgrade pip

echo "Installing Python packages..."
pip install -r requirements.txt

echo "Creating backend .env..."
cat > .env <<EOF
MONGO_URL=$MONGO_URL
DB_NAME=$DB_NAME
CORS_ORIGINS=*
EOF

echo "Backend .env created:"
cat .env

echo ""
echo "========== STEP 9: SETUP FRONTEND =========="
cd /opt/app/frontend

echo "Creating frontend .env..."
cat > .env <<EOF
REACT_APP_BACKEND_URL=http://$SERVER_IP
PORT=3000
EOF

echo "Frontend .env created:"
cat .env

echo ""
echo "Installing Node packages (THIS TAKES 3-5 MINUTES)..."
echo "You'll see packages installing below:"
yarn install --frozen-lockfile

echo ""
echo "========== STEP 10: CONFIGURE SERVICES =========="

echo "Creating supervisor config..."
cat > /etc/supervisor/conf.d/app.conf <<EOF
[program:backend]
command=/opt/app/venv/bin/uvicorn server:app --host 0.0.0.0 --port 8001 --workers 2
directory=/opt/app/backend
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/backend.err.log
stdout_logfile=/var/log/supervisor/backend.out.log

[program:frontend]
command=yarn start
directory=/opt/app/frontend
user=root
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/frontend.err.log
stdout_logfile=/var/log/supervisor/frontend.out.log
environment=HOST="0.0.0.0",PORT="3000"
EOF

echo "Reloading supervisor..."
supervisorctl reread
supervisorctl update

echo "Starting services..."
supervisorctl start all

echo ""
echo "Current service status:"
supervisorctl status

echo ""
echo "========== STEP 11: CONFIGURE NGINX =========="

echo "Creating nginx config..."
cat > /etc/nginx/sites-available/app <<EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}
EOF

echo "Enabling site..."
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default

echo "Testing nginx config..."
nginx -t

echo "Restarting nginx..."
systemctl restart nginx

echo ""
echo "======================================"
echo "INSTALLATION COMPLETE!"
echo "======================================"
echo ""
echo "Your application: http://$SERVER_IP"
echo "API docs: http://$SERVER_IP/api/docs"
echo ""
echo "Check services:"
echo "  sudo supervisorctl status"
echo ""
echo "View logs:"
echo "  sudo tail -f /var/log/supervisor/backend.out.log"
echo "  sudo tail -f /var/log/supervisor/frontend.out.log"
echo ""
