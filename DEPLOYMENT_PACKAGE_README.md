# 🚀 FastAPI + React Deployment Package

Complete deployment solution for Ubuntu 22.04 AWS EC2 instances. This package provides automated installation, deployment, and management scripts for FastAPI + React applications with MongoDB.

## 📦 Package Contents

```
.
├── install.sh              # System dependencies installer
├── deploy.sh              # Application deployment script
├── setup_supervisor.sh    # Supervisor process manager setup
├── quick_start.sh         # Interactive setup wizard
├── health_check.sh        # Application health checker
├── logs.sh               # Log viewing utility
├── docker-compose.yml    # Docker Compose configuration
├── Dockerfile            # Docker image definition
├── .env.example          # Environment variables template
├── docker/
│   ├── supervisord.conf  # Supervisor config for Docker
│   └── nginx.conf        # Nginx config for Docker
└── README_DEPLOYMENT.md  # Comprehensive deployment guide
```

## ⚡ Quick Start (3 Commands)

For the fastest setup, use the interactive wizard:

```bash
# 1. Download the deployment package to your Ubuntu 22.04 server
scp -r deployment-package/ ubuntu@your-server-ip:/tmp/

# 2. SSH into the server
ssh ubuntu@your-server-ip

# 3. Run the quick start wizard
cd /tmp/deployment-package
sudo chmod +x quick_start.sh
sudo ./quick_start.sh
```

The wizard will:
- ✅ Install all dependencies (Python, Node.js, MongoDB, Nginx)
- ✅ Clone your git repository
- ✅ Configure environment variables
- ✅ Setup process management
- ✅ Deploy and start your application

**That's it!** Your application will be running at `http://your-server-ip`

## 🎯 Deployment Methods

### Option 1: Quick Start (Recommended for First-Time Users)

Interactive setup with guided configuration:

```bash
sudo ./quick_start.sh
```

### Option 2: Manual Step-by-Step

Full control over each step:

```bash
# 1. Install system dependencies
sudo ./install.sh

# 2. Configure environment
cp .env.example .env
nano .env  # Edit with your settings

# 3. Clone your repository
export GIT_REPO="https://github.com/yourusername/your-repo.git"
git clone $GIT_REPO /opt/app

# 4. Setup process management
cd /opt/app
sudo ./setup_supervisor.sh

# 5. Deploy application
sudo -E ./deploy.sh
```

### Option 3: Docker Deployment

Containerized deployment for ephemeral environments:

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Clone your repository
git clone https://github.com/yourusername/your-repo.git
cd your-repo

# Configure environment
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env

# Build and run
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

## 📋 Prerequisites

### Server Requirements

- **OS**: Ubuntu 22.04 LTS
- **Instance**: t2.medium or higher (4GB+ RAM)
- **Storage**: 20GB+ SSD
- **Network**: Open ports 22, 80, 443

### AWS Security Group

```
Port 22  - SSH
Port 80  - HTTP
Port 443 - HTTPS
```

## 🔧 What Gets Installed

### System Components

- **Python 3.11** - Backend runtime
- **Node.js 20.x** - Frontend runtime
- **Yarn** - Package manager
- **MongoDB 7.0** - Database
- **Nginx** - Reverse proxy
- **Supervisor** - Process manager

### Application Architecture

```
Internet
    ↓
Nginx (Port 80/443)
    ├─→ React Frontend (Port 3000)
    └─→ FastAPI Backend (Port 8001)
            ↓
        MongoDB (Port 27017)
```

## 🛠️ Useful Scripts

### Health Check

Check if all services are running:

```bash
cd /opt/app
./health_check.sh
```

Output:
```
System Services:
----------------
Checking MongoDB (port 27017)... ✓ OK
Checking Backend (port 8001)... ✓ OK
Checking Frontend (port 3000)... ✓ OK
Checking Nginx (port 80)... ✓ OK
```

### View Logs

Convenient log viewing:

```bash
# View backend logs (last 50 lines)
./logs.sh backend

# Follow backend logs in real-time
./logs.sh backend -f

# View last 100 lines
./logs.sh backend -n 100

# View error logs only
./logs.sh backend -e

# View all logs
./logs.sh all
```

### Redeploy from Git

Pull latest changes and redeploy:

```bash
cd /opt/app
sudo -E ./deploy.sh
```

Features:
- ✅ Automatic backup before deployment
- ✅ Pulls latest code from git
- ✅ Installs/updates dependencies
- ✅ Restarts services
- ✅ Health check validation
- ✅ Automatic rollback on failure

## 📊 Management Commands

### Service Control

```bash
# Check status
sudo supervisorctl status

# Restart all services
sudo supervisorctl restart app:*

# Restart individual services
sudo supervisorctl restart backend
sudo supervisorctl restart frontend

# Stop services
sudo supervisorctl stop app:*

# Start services
sudo supervisorctl start app:*
```

### View Logs

```bash
# Backend logs
sudo supervisorctl tail -f backend

# Frontend logs
sudo supervisorctl tail -f frontend

# Or directly
tail -f /var/log/supervisor/backend.out.log
tail -f /var/log/supervisor/backend.err.log
```

### Database Management

```bash
# Access MongoDB shell
mongosh

# Backup database
mongodump --db app_database --out /backup/$(date +%Y%m%d)

# Restore database
mongorestore --db app_database /backup/20240101/app_database
```

## 🔄 Continuous Deployment

### Setup Git Webhooks

Add webhook to your repository that calls:

```bash
curl -X POST http://your-server-ip:8080/deploy
```

### Create Webhook Handler

```bash
# Install webhook handler
sudo apt-get install webhook

# Create webhook configuration
sudo nano /etc/webhook.conf
```

```json
[
  {
    "id": "deploy",
    "execute-command": "/opt/app/deploy.sh",
    "command-working-directory": "/opt/app"
  }
]
```

```bash
# Start webhook service
webhook -hooks /etc/webhook.conf -verbose
```

## 🐳 Docker Operations

### Basic Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Rebuild and restart
docker-compose up -d --build

# View status
docker-compose ps
```

### Access Container

```bash
# Shell access
docker-compose exec app bash

# Check supervisor status
docker-compose exec app supervisorctl status

# View backend logs
docker-compose exec app tail -f /var/log/supervisor/backend.out.log
```

### Data Persistence

MongoDB data is stored in Docker volumes:

```bash
# List volumes
docker volume ls

# Backup volume
docker run --rm -v mongodb_data:/data -v $(pwd):/backup ubuntu tar czf /backup/mongodb_backup.tar.gz /data

# Restore volume
docker run --rm -v mongodb_data:/data -v $(pwd):/backup ubuntu tar xzf /backup/mongodb_backup.tar.gz -C /
```

## 🔒 Security Best Practices

### Firewall Setup

```bash
sudo ufw enable
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw status
```

### MongoDB Authentication

Enable MongoDB authentication in production:

```bash
# Access MongoDB
mongosh

# Create admin user
use admin
db.createUser({
  user: "admin",
  pwd: "secure_password",
  roles: ["userAdminAnyDatabase"]
})

# Update MONGO_URL in backend/.env
MONGO_URL=mongodb://admin:secure_password@localhost:27017
```

### SSL/TLS (HTTPS)

Setup Let's Encrypt SSL:

```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
sudo certbot renew --dry-run  # Test renewal
```

### Environment Security

```bash
# Restrict .env file access
chmod 600 /opt/app/backend/.env
chmod 600 /opt/app/frontend/.env
chown appuser:appuser /opt/app/backend/.env
chown appuser:appuser /opt/app/frontend/.env
```

## 🐛 Troubleshooting

### Services Not Starting

```bash
# Check supervisor status
sudo supervisorctl status

# View error logs
tail -f /var/log/supervisor/backend.err.log

# Check if ports are in use
sudo lsof -i :8001
sudo lsof -i :3000

# Restart services
sudo supervisorctl restart app:*
```

### MongoDB Connection Issues

```bash
# Check MongoDB status
sudo systemctl status mongod

# Restart MongoDB
sudo systemctl restart mongod

# Check connection
mongosh mongodb://localhost:27017
```

### Nginx Issues

```bash
# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# View error logs
tail -f /var/log/nginx/error.log
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R appuser:appuser /opt/app

# Fix permissions
sudo chmod -R 755 /opt/app
```

## 📈 Performance Tuning

### Increase Backend Workers

Edit `/etc/supervisor/conf.d/app.conf`:

```ini
command=/opt/app/venv/bin/uvicorn server:app --host 0.0.0.0 --port 8001 --workers 4
```

### Build Frontend for Production

```bash
cd /opt/app/frontend
yarn build
```

Configure Nginx to serve static files:

```nginx
location / {
    root /opt/app/frontend/build;
    try_files $uri /index.html;
}
```

### Enable Caching

Add to Nginx config:

```nginx
location /static {
    alias /opt/app/frontend/build/static;
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

## 📚 Additional Resources

- **Full Documentation**: See `README_DEPLOYMENT.md`
- **Docker Guide**: See Docker section in deployment docs
- **API Documentation**: http://your-server-ip:8001/docs (FastAPI auto-docs)

## 🤝 Support

### Common Issues

1. **Port conflicts**: Check with `sudo lsof -i :PORT`
2. **Permission denied**: Run with `sudo` or fix ownership
3. **Module not found**: Re-run deployment to install dependencies
4. **Database connection**: Check MongoDB status and .env file

### Get Help

```bash
# Run health check
./health_check.sh

# View all logs
./logs.sh all

# Check system resources
htop
df -h
```

## 📝 File Checklist

Before deployment, ensure you have:

- [ ] `install.sh` - Executable (`chmod +x`)
- [ ] `deploy.sh` - Executable (`chmod +x`)
- [ ] `setup_supervisor.sh` - Executable (`chmod +x`)
- [ ] `.env` - Configured with your git repository
- [ ] `backend/.env` - MongoDB and CORS settings
- [ ] `frontend/.env` - Backend URL configured

## 🎉 Success Indicators

After successful deployment, you should see:

✅ All services running in Supervisor
✅ Backend API responding at `/api/`
✅ Frontend accessible at port 3000
✅ Nginx proxy working on port 80
✅ MongoDB running on port 27017
✅ Health checks passing

Test with:
```bash
curl http://localhost/api/
curl http://localhost/
./health_check.sh
```

---

## 📄 License

This deployment package is provided as-is for use with your FastAPI + React applications.

**Happy Deploying! 🚀**
