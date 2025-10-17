#!/bin/bash
################################################################################
# Enable HTTPS with Let's Encrypt SSL
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}              ${GREEN}🔒 ENABLE HTTPS WITH SSL 🔒${NC}                     ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: Run with sudo${NC}"
    exit 1
fi

# Get domain name
echo -e "${YELLOW}Important:${NC} Your domain must already point to this server's IP!"
echo ""
read -p "Enter your domain name (e.g., yourdomain.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain name is required!${NC}"
    exit 1
fi

read -p "Enter your email for SSL certificate: " EMAIL

if [ -z "$EMAIL" ]; then
    echo -e "${RED}Email is required!${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "Continue? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "======================================"
echo "Step 1: Installing Certbot"
echo "======================================"
echo ""

# Install certbot
apt-get update
apt-get install -y certbot

echo ""
echo -e "${GREEN}✓ Certbot installed${NC}"

echo ""
echo "======================================"
echo "Step 2: Stopping container temporarily"
echo "======================================"
echo ""

# Stop container to free port 80
docker-compose -f docker-compose.simple.yml down

echo ""
echo "======================================"
echo "Step 3: Obtaining SSL Certificate"
echo "======================================"
echo ""

# Get certificate (standalone mode)
certbot certonly --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to obtain certificate!${NC}"
    echo "Make sure:"
    echo "  1. Domain points to this server"
    echo "  2. Port 80 is accessible from internet"
    echo "  3. Domain is valid"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ SSL Certificate obtained!${NC}"

echo ""
echo "======================================"
echo "Step 4: Creating HTTPS Nginx Config"
echo "======================================"
echo ""

# Create new nginx config with SSL
cat > /tmp/nginx-https.conf <<EOF
# HTTP - Redirect to HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    client_max_body_size 100M;
    
    # Frontend
    location / {
        proxy_pass http://localhost:3000;
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
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:8001/api/;
        access_log off;
    }
}
EOF

echo -e "${GREEN}✓ HTTPS configuration created${NC}"

echo ""
echo "======================================"
echo "Step 5: Updating docker-compose.yml"
echo "======================================"
echo ""

# Update docker-compose to expose port 443 and mount certificates
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
      - BACKEND_URL=https://$DOMAIN:8001
      - CORS_ORIGINS=\${CORS_ORIGINS:-*}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  mongodb_data:
EOF

echo -e "${GREEN}✓ Docker Compose updated${NC}"

echo ""
echo "======================================"
echo "Step 6: Updating Frontend .env"
echo "======================================"
echo ""

# Update .env to use HTTPS
sed -i "s|BACKEND_URL=.*|BACKEND_URL=https://$DOMAIN|" .env

echo -e "${GREEN}✓ Environment updated${NC}"

echo ""
echo "======================================"
echo "Step 7: Starting Container with HTTPS"
echo "======================================"
echo ""

docker-compose -f docker-compose.simple.yml up -d

echo ""
echo "Waiting for services to start (30 seconds)..."
sleep 30

echo ""
echo "======================================"
echo "Step 8: Checking Status"
echo "======================================"
echo ""

docker exec cloudvoro-adops supervisorctl status

echo ""
echo "======================================"
echo "Step 9: Setting Up Auto-Renewal"
echo "======================================"
echo ""

# Get current directory
CURRENT_DIR=$(pwd)

# Create renewal script
cat > /usr/local/bin/renew-ssl.sh <<EOF
#!/bin/bash
# SSL Certificate Auto-Renewal Script

LOG_FILE="/var/log/ssl-renewal.log"

echo "\$(date): Starting SSL renewal check" >> \$LOG_FILE

# Try to renew
certbot renew --quiet >> \$LOG_FILE 2>&1

if [ \$? -eq 0 ]; then
    echo "\$(date): Renewal check completed successfully" >> \$LOG_FILE
    
    # Restart container if certificates were renewed
    cd $CURRENT_DIR
    docker-compose -f docker-compose.simple.yml restart >> \$LOG_FILE 2>&1
    
    echo "\$(date): Container restarted" >> \$LOG_FILE
else
    echo "\$(date): Renewal check failed" >> \$LOG_FILE
fi
EOF

chmod +x /usr/local/bin/renew-ssl.sh

# Add to crontab (run twice daily at 3am and 3pm)
CRON_JOB="0 3,15 * * * /usr/local/bin/renew-ssl.sh"

# Check if cron job already exists
(crontab -l 2>/dev/null | grep -v "renew-ssl.sh"; echo "$CRON_JOB") | crontab -

echo -e "${GREEN}✓ Auto-renewal cron job configured${NC}"
echo "  - Runs twice daily (3 AM and 3 PM)"
echo "  - Logs to /var/log/ssl-renewal.log"

# Test the renewal (dry run)
echo ""
echo "Testing renewal process (dry run)..."
certbot renew --dry-run

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Renewal test passed${NC}"
else
    echo -e "${YELLOW}⚠ Renewal test had issues, but setup is complete${NC}"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo -e "║                    ${GREEN}🎉 HTTPS ENABLED! 🎉${NC}                        ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Your application is now secured with HTTPS!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${GREEN}🔒 HTTPS URL:${NC}  https://$DOMAIN"
echo -e "  ${GREEN}📡 API Docs:${NC}   https://$DOMAIN/api/docs"
echo ""
echo -e "${YELLOW}Note: HTTP requests are automatically redirected to HTTPS${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Auto-Renewal Configured:${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  ✓ Certificates will auto-renew before expiration (90 days)"
echo "  ✓ Renewal checks run twice daily (3 AM and 3 PM)"
echo "  ✓ Container automatically restarts after renewal"
echo "  ✓ Renewal logs: /var/log/ssl-renewal.log"
echo ""
echo "Manual renewal (if needed):"
echo "  sudo certbot renew"
echo "  docker-compose -f docker-compose.simple.yml restart"
echo ""
echo "Check renewal logs:"
echo "  tail -f /var/log/ssl-renewal.log"
echo ""
echo "View cron jobs:"
echo "  crontab -l"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
