#!/bin/bash
# COMPLETE DEPLOYMENT WITH OPTIONAL HTTPS

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "======================================"
echo "COMPLETE DOCKER DEPLOYMENT"
echo "======================================"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Run with sudo"
    exit 1
fi

# Check Docker Compose
if docker compose version &> /dev/null 2>&1; then
    DC="docker compose"
elif docker-compose --version &> /dev/null 2>&1; then
    DC="docker-compose"
else
    echo "ERROR: Docker Compose not found"
    exit 1
fi

echo "✓ Using: $DC"
echo ""

# Configuration
echo "Configuration:"
read -p "GitHub repo URL: " GIT_REPO
read -p "Branch (default: main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}

echo ""
read -p "Do you have a domain name? (y/n): " HAS_DOMAIN

if [ "$HAS_DOMAIN" = "y" ] || [ "$HAS_DOMAIN" = "Y" ]; then
    USE_HTTPS=true
    read -p "Domain name (e.g., yourdomain.com): " DOMAIN
    read -p "Email for SSL certificate: " EMAIL
    SERVER_URL="https://$DOMAIN"
else
    USE_HTTPS=false
    SERVER_IP=$(curl -s ifconfig.me || echo "localhost")
    SERVER_URL="http://$SERVER_IP"
fi

echo ""
read -p "Database (1=self-hosted, 2=atlas): " DB_CHOICE

if [ "$DB_CHOICE" = "2" ]; then
    read -p "MongoDB Atlas URL: " MONGO_URL
else
    MONGO_URL="mongodb://localhost:27017"
    read -p "Database name (default: app_database): " DB_NAME
    DB_NAME=${DB_NAME:-app_database}
fi

# Save basic config
cat > .env <<EOF
GIT_REPO=$GIT_REPO
GIT_BRANCH=$GIT_BRANCH
MONGO_URL=$MONGO_URL
DB_NAME=${DB_NAME:-app_database}
BACKEND_URL=$SERVER_URL
CORS_ORIGINS=*
EOF

echo ""
echo "Configuration saved:"
cat .env
echo ""

if [ "$USE_HTTPS" = true ]; then
    echo -e "${YELLOW}HTTPS will be enabled after build${NC}"
    echo ""
fi

read -p "Press Enter to build (10 minutes first time)..."

echo ""
echo "======================================"
echo "Building Container"
echo "======================================"
echo ""

$DC -f docker-compose.simple.yml build

echo ""
echo "======================================"
echo "Starting Container (HTTP mode)"
echo "======================================"
echo ""

$DC -f docker-compose.simple.yml down 2>/dev/null || true
$DC -f docker-compose.simple.yml up -d

echo ""
echo "Waiting for startup (30 seconds)..."
sleep 30

if [ "$USE_HTTPS" = false ]; then
    echo ""
    echo "======================================"
    echo "SUCCESS!"
    echo "======================================"
    echo ""
    echo "Application: $SERVER_URL"
    echo "API Docs:    $SERVER_URL/api/docs"
    echo ""
    exit 0
fi

# Enable HTTPS
echo ""
echo "======================================"
echo "Installing Certbot"
echo "======================================"
echo ""

apt-get update > /dev/null 2>&1
apt-get install -y certbot

echo ""
echo "======================================"
echo "Obtaining SSL Certificate"
echo "======================================"
echo ""

# Stop container for certbot
$DC -f docker-compose.simple.yml down

# Get certificate
certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN"

if [ $? -ne 0 ]; then
    echo -e "${RED}SSL certificate failed!${NC}"
    echo "Starting without HTTPS..."
    $DC -f docker-compose.simple.yml up -d
    exit 1
fi

echo ""
echo -e "${GREEN}✓ SSL Certificate obtained${NC}"

# Create HTTPS nginx config
cat > /tmp/nginx-https.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    client_max_body_size 100M;
    
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

# Update docker-compose for HTTPS
cat > docker-compose.simple.yml <<EOF
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.simple
      args:
        GIT_REPO: \${GIT_REPO}
        GIT_BRANCH: \${GIT_BRANCH:-main}
    container_name: cloudvoro-adops
    ports:
      - "80:80"
      - "443:443"
      - "3000:3000"
      - "8001:8001"
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
      - ./logs:/var/log/supervisor
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - /tmp/nginx-https.conf:/etc/nginx/sites-available/default:ro
    environment:
      - MONGO_URL=\${MONGO_URL:-mongodb://localhost:27017}
      - DB_NAME=\${DB_NAME:-app_database}
      - BACKEND_URL=https://$DOMAIN
      - CORS_ORIGINS=\${CORS_ORIGINS:-*}
    restart: unless-stopped

volumes:
  mongodb_data:
EOF

# Update .env
sed -i "s|BACKEND_URL=.*|BACKEND_URL=https://$DOMAIN|" .env

echo ""
echo "======================================"
echo "Starting with HTTPS"
echo "======================================"
echo ""

$DC -f docker-compose.simple.yml up -d

echo ""
echo "Waiting for startup (30 seconds)..."
sleep 30

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo -e "║                    ${GREEN}🎉 SUCCESS! 🎉${NC}                             ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}✅ Your application is deployed with HTTPS!${NC}"
echo ""
echo -e "  ${GREEN}🔒 Application:${NC}  https://$DOMAIN"
echo -e "  ${GREEN}📡 API Docs:${NC}     https://$DOMAIN/api/docs"
echo ""
echo -e "${YELLOW}HTTP requests automatically redirect to HTTPS${NC}"
echo ""
echo "Certificate auto-renews. Manual renewal:"
echo "  sudo certbot renew"
echo "  $DC -f docker-compose.simple.yml restart"
echo ""
