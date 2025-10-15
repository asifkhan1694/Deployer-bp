# FastAPI + React Application Deployment Guide

Complete deployment guide for Ubuntu 22.04 AWS EC2 instances with support for both traditional VM deployment and containerized deployment.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Methods](#deployment-methods)
  - [Method 1: Traditional VM Deployment](#method-1-traditional-vm-deployment)
  - [Method 2: Docker Deployment](#method-2-docker-deployment)
- [Configuration](#configuration)
- [Management & Operations](#management--operations)
- [Troubleshooting](#troubleshooting)
- [Production Best Practices](#production-best-practices)

---

## 🎯 Overview

This deployment package provides automated scripts and configurations to deploy a FastAPI + React application on Ubuntu 22.04 servers. It includes:

- **Backend**: FastAPI with MongoDB (Motor async driver)
- **Frontend**: React with Create React App + Craco
- **Database**: MongoDB 7.0
- **Process Manager**: Supervisor
- **Web Server**: Nginx (reverse proxy)

### Architecture

```
Internet → Nginx (Port 80/443)
           ├─→ Frontend (Port 3000) → React App
           └─→ Backend API (Port 8001) → FastAPI → MongoDB (Port 27017)
```

---

## 📦 Prerequisites

### AWS EC2 Instance Requirements

- **OS**: Ubuntu 22.04 LTS (ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20250822)
- **Instance Type**: t2.medium or higher (minimum 4GB RAM recommended)
- **Storage**: 20GB+ SSD
- **Security Group Rules**:
  - Port 22 (SSH)
  - Port 80 (HTTP)
  - Port 443 (HTTPS)
  - Optional: Port 3000, 8001 for direct access during development

### Required Tools

- Git
- SSH access to the server
- (Optional) Docker and Docker Compose for containerized deployment

---

## 🚀 Quick Start

### 1. Connect to Your Server

```bash
ssh ubuntu@your-server-ip
```

### 2. Clone Your Repository

```bash
cd /tmp
git clone https://github.com/yourusername/your-repo.git
cd your-repo
```

### 3. Run the Installer

```bash
sudo chmod +x install.sh
sudo ./install.sh
```

This will install all system dependencies (Python, Node.js, MongoDB, Nginx, Supervisor).

### 4. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your configuration
nano .env
```

Set your `GIT_REPO` and other variables:

```bash
GIT_REPO=https://github.com/yourusername/your-repo.git
GIT_BRANCH=main
APP_DIR=/opt/app
```

### 5. Setup Application

```bash
# Move to application directory
sudo mkdir -p /opt/app
sudo cp -r * /opt/app/
cd /opt/app

# Setup Supervisor
sudo chmod +x setup_supervisor.sh
sudo ./setup_supervisor.sh
```

### 6. Deploy

```bash
sudo chmod +x deploy.sh
source .env
sudo -E ./deploy.sh
```

Your application should now be running!

- **Frontend**: http://your-server-ip
- **Backend API**: http://your-server-ip/api/
- **Health Check**: http://your-server-ip/health

---

## 🔧 Deployment Methods

### Method 1: Traditional VM Deployment

This method installs all components directly on the Ubuntu server.

#### Step-by-Step Installation

**1. System Preparation**

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Run installer
sudo ./install.sh
```

The installer will:
- ✅ Install Python 3.11
- ✅ Install Node.js 20.x and Yarn
- ✅ Install MongoDB 7.0
- ✅ Configure Nginx as reverse proxy
- ✅ Setup Supervisor for process management
- ✅ Configure firewall (UFW)

**2. Application Deployment**

```bash
# Set environment variables
export GIT_REPO="https://github.com/yourusername/your-repo.git"
export GIT_BRANCH="main"
export APP_DIR="/opt/app"

# Deploy application
sudo -E ./deploy.sh
```

**3. Setup Process Management**

```bash
sudo ./setup_supervisor.sh
```

#### Managing Services

```bash
# Check status
sudo supervisorctl status

# Restart all services
sudo supervisorctl restart app:*

# Restart individual services
sudo supervisorctl restart backend
sudo supervisorctl restart frontend

# View logs
sudo supervisorctl tail -f backend
sudo supervisorctl tail -f frontend

# Or directly
tail -f /var/log/supervisor/backend.out.log
tail -f /var/log/supervisor/backend.err.log
```

#### Redeployment

To deploy updates from git:

```bash
cd /opt/app
sudo -E ./deploy.sh
```

The script will:
1. Create a backup of the current deployment
2. Pull latest code from git
3. Install/update dependencies
4. Restart services
5. Perform health checks
6. Rollback automatically if health checks fail

---

### Method 2: Docker Deployment

Containerized deployment using Docker and Docker Compose.

#### Prerequisites

Install Docker:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### Building and Running

**Development Mode** (with hot reload):

```bash
# Clone repository
git clone https://github.com/yourusername/your-repo.git
cd your-repo

# Create environment files
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env

# Edit environment files as needed
nano backend/.env
nano frontend/.env

# Build and start
docker-compose up -d

# View logs
docker-compose logs -f
```

**Production Mode**:

```bash
# Modify docker-compose.yml to remove volume mounts
# Build frontend for production
docker-compose build

# Start services
docker-compose up -d
```

#### Managing Docker Containers

```bash
# View status
docker-compose ps

# View logs
docker-compose logs -f app
docker-compose logs -f nginx

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Rebuild and restart
docker-compose up -d --build

# Clean up
docker-compose down -v  # Removes volumes (WARNING: deletes database data)
```

#### Accessing Containers

```bash
# Access app container shell
docker-compose exec app bash

# Check MongoDB
docker-compose exec app mongosh

# View supervisor status
docker-compose exec app supervisorctl status
```

---

## ⚙️ Configuration

### Environment Variables

#### Backend (.env in /app/backend/)

```bash
# MongoDB Configuration
MONGO_URL=mongodb://localhost:27017
DB_NAME=app_database

# CORS Configuration
CORS_ORIGINS=*  # In production, set specific domains

# Optional: Add your API keys
# OPENAI_API_KEY=your_key_here
```

#### Frontend (.env in /app/frontend/)

```bash
# Backend API URL
REACT_APP_BACKEND_URL=http://localhost:8001

# Port Configuration
PORT=3000
HOST=0.0.0.0

# Optional: Feature flags
# REACT_APP_ENABLE_ANALYTICS=true
```

### Nginx Configuration

Edit `/etc/nginx/sites-available/app` for custom domains or SSL:

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    # Add SSL configuration here
    # listen 443 ssl;
    # ssl_certificate /path/to/cert.pem;
    # ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:3000;
        # ... rest of configuration
    }

    location /api {
        proxy_pass http://localhost:8001;
        # ... rest of configuration
    }
}
```

Reload Nginx after changes:

```bash
sudo nginx -t  # Test configuration
sudo systemctl reload nginx
```

### Supervisor Configuration

Custom supervisor config at `/etc/supervisor/conf.d/app.conf`

To modify worker count or add environment variables:

```ini
[program:backend]
command=/opt/app/venv/bin/uvicorn server:app --host 0.0.0.0 --port 8001 --workers 4
environment=PATH="/opt/app/venv/bin",CUSTOM_VAR="value"
```

Reload supervisor:

```bash
sudo supervisorctl reread
sudo supervisorctl update
```

---

## 🛠️ Management & Operations

### Monitoring

**Check Service Status:**

```bash
# Supervisor status
sudo supervisorctl status

# System services
sudo systemctl status mongod
sudo systemctl status nginx

# Port usage
sudo netstat -tulpn | grep -E ':(3000|8001|27017)'
```

**View Logs:**

```bash
# Application logs
tail -f /var/log/supervisor/backend.out.log
tail -f /var/log/supervisor/frontend.out.log

# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# MongoDB logs
tail -f /var/log/mongodb/mongod.log
```

### Backup and Restore

**Backup MongoDB:**

```bash
# Create backup
mongodump --db app_database --out /backup/$(date +%Y%m%d)

# Restore backup
mongorestore --db app_database /backup/20240101/app_database
```

**Backup Application:**

```bash
# Automated backups are created in /opt/app_backups/ during deployment
ls -lh /opt/app_backups/

# Manual backup
sudo tar -czf /backup/app_$(date +%Y%m%d).tar.gz /opt/app
```

### Rollback

**Automatic Rollback:**

The deployment script automatically rolls back if health checks fail.

**Manual Rollback:**

```bash
# List backups
ls -lh /opt/app_backups/

# Restore from backup
sudo rm -rf /opt/app
sudo cp -r /opt/app_backups/backup_20240101_120000 /opt/app
sudo supervisorctl restart app:*
```

### Database Management

**Access MongoDB Shell:**

```bash
mongosh
```

**Common MongoDB Commands:**

```javascript
// Switch to database
use app_database

// View collections
show collections

// Query documents
db.status_checks.find()

// Create index
db.status_checks.createIndex({ timestamp: -1 })

// Backup specific collection
db.status_checks.find().forEach(function(doc) { printjson(doc); })
```

---

## 🔍 Troubleshooting

### Common Issues

#### 1. Services Not Starting

**Check logs:**

```bash
sudo supervisorctl status
tail -f /var/log/supervisor/backend.err.log
```

**Common causes:**
- Port already in use: `sudo lsof -i :8001` or `sudo lsof -i :3000`
- Missing dependencies: Re-run deployment script
- MongoDB not running: `sudo systemctl start mongod`

#### 2. Frontend Can't Connect to Backend

**Check:**
- Backend is running: `curl http://localhost:8001/api/`
- Frontend .env has correct REACT_APP_BACKEND_URL
- CORS settings in backend .env
- Nginx configuration is correct

**Fix:**

```bash
# Restart all services
sudo supervisorctl restart app:*
sudo systemctl restart nginx

# Check Nginx logs
tail -f /var/log/nginx/error.log
```

#### 3. MongoDB Connection Issues

**Check MongoDB status:**

```bash
sudo systemctl status mongod
sudo lsof -i :27017
```

**Restart MongoDB:**

```bash
sudo systemctl restart mongod
```

**Check connection:**

```bash
mongosh mongodb://localhost:27017
```

#### 4. Port Already in Use

```bash
# Find process using port
sudo lsof -i :8001
sudo lsof -i :3000

# Kill process
sudo kill -9 <PID>

# Or restart supervisor
sudo supervisorctl restart app:*
```

#### 5. Permission Issues

```bash
# Fix ownership
sudo chown -R appuser:appuser /opt/app
sudo chmod -R 755 /opt/app

# Fix log permissions
sudo chown -R appuser:appuser /var/log/supervisor
```

### Debug Mode

**Enable verbose logging in backend:**

Edit `/opt/app/backend/server.py`:

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

**Enable React debug mode:**

```bash
# In frontend/.env
REACT_APP_DEBUG=true
```

### Health Checks

**Backend health:**

```bash
curl http://localhost:8001/api/
```

**Frontend health:**

```bash
curl http://localhost:3000
```

**Full stack health:**

```bash
curl http://localhost/health
```

---

## 🔒 Production Best Practices

### Security

**1. Firewall Configuration:**

```bash
# Only allow necessary ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

**2. MongoDB Security:**

```bash
# Enable authentication
sudo nano /etc/mongod.conf
```

Add:

```yaml
security:
  authorization: enabled
```

Create admin user:

```javascript
mongosh
use admin
db.createUser({
  user: "admin",
  pwd: "secure_password",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
})
```

Update MONGO_URL:

```bash
MONGO_URL=mongodb://admin:secure_password@localhost:27017
```

**3. SSL/TLS Configuration:**

Install certbot for Let's Encrypt:

```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

**4. Environment Variables:**

Never commit `.env` files to git. Use secure storage:

```bash
# Restrict access
chmod 600 /opt/app/backend/.env
chmod 600 /opt/app/frontend/.env
```

### Performance Optimization

**1. Increase Uvicorn Workers:**

Edit supervisor config:

```ini
command=/opt/app/venv/bin/uvicorn server:app --host 0.0.0.0 --port 8001 --workers 4
```

**2. Build Frontend for Production:**

```bash
cd /opt/app/frontend
yarn build
```

Configure Nginx to serve static build:

```nginx
location / {
    root /opt/app/frontend/build;
    try_files $uri /index.html;
}
```

**3. Enable Nginx Caching:**

```nginx
location /static {
    alias /opt/app/frontend/build/static;
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

**4. MongoDB Indexing:**

```javascript
// Create indexes for frequently queried fields
db.status_checks.createIndex({ timestamp: -1 })
db.status_checks.createIndex({ client_name: 1 })
```

### Monitoring & Logging

**1. Setup Log Rotation:**

```bash
sudo nano /etc/logrotate.d/app
```

```
/var/log/supervisor/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 appuser appuser
    postrotate
        supervisorctl restart app:*
    endscript
}
```

**2. Application Monitoring:**

Consider installing monitoring tools:

```bash
# Install monitoring stack (optional)
# Prometheus + Grafana
# Or use cloud-based solutions like DataDog, New Relic
```

**3. Health Check Endpoint:**

Add monitoring endpoint in backend:

```python
@api_router.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "database": "connected" if db else "disconnected",
        "timestamp": datetime.now().isoformat()
    }
```

### Backup Strategy

**Automated Backup Script:**

Create `/opt/scripts/backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/backup/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup MongoDB
mongodump --db app_database --out $BACKUP_DIR

# Backup application
tar -czf $BACKUP_DIR/app.tar.gz /opt/app

# Keep only last 7 days
find /backup -type d -mtime +7 -exec rm -rf {} +
```

Add to crontab:

```bash
sudo crontab -e
# Add: 0 2 * * * /opt/scripts/backup.sh
```

---

## 📞 Support & Additional Resources

### Useful Commands Reference

```bash
# Deployment
sudo -E ./deploy.sh              # Deploy/redeploy application

# Service Management
sudo supervisorctl status         # Check all services
sudo supervisorctl restart app:*  # Restart all app services
sudo systemctl restart nginx      # Restart Nginx
sudo systemctl restart mongod     # Restart MongoDB

# Logs
tail -f /var/log/supervisor/backend.out.log
tail -f /var/log/nginx/error.log

# Health Checks
curl http://localhost:8001/api/
curl http://localhost:3000
curl http://localhost/health

# Database
mongosh                          # Access MongoDB shell

# Docker
docker-compose up -d             # Start containers
docker-compose logs -f           # View logs
docker-compose restart           # Restart services
```

### Architecture Diagram

```
┌─────────────────────────────────────────────┐
│              AWS EC2 Instance               │
│         Ubuntu 22.04 LTS                    │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │         Nginx (Port 80/443)          │  │
│  │       (Reverse Proxy & SSL)          │  │
│  └────────────┬─────────────────────────┘  │
│               │                             │
│       ┌───────┴─────────┐                   │
│       │                 │                   │
│   ┌───▼────┐      ┌────▼────┐              │
│   │Frontend│      │ Backend │              │
│   │  React │      │ FastAPI │              │
│   │ :3000  │      │  :8001  │              │
│   └────────┘      └────┬────┘              │
│                        │                    │
│                   ┌────▼────┐               │
│                   │ MongoDB │               │
│                   │ :27017  │               │
│                   └─────────┘               │
│                                             │
│        All managed by Supervisor           │
└─────────────────────────────────────────────┘
```

---

## 🎉 Conclusion

You now have a production-ready deployment setup for your FastAPI + React application on Ubuntu 22.04. The system includes:

- ✅ Automated deployment with rollback capability
- ✅ Process management via Supervisor
- ✅ Reverse proxy with Nginx
- ✅ MongoDB database
- ✅ Health monitoring
- ✅ Backup system
- ✅ Docker support for containerized deployment

For questions or issues, refer to the troubleshooting section or check the logs for detailed error messages.

Happy deploying! 🚀
