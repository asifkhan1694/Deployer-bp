# 🐳 Docker-Based Deployment Guide

## Why Docker? Zero Dependency Issues!

### Problems with Traditional Installation
- ❌ Package manager conflicts
- ❌ Python/Node.js version issues
- ❌ System dependency hell
- ❌ "Works on my machine" problems
- ❌ Different Ubuntu configurations

### Docker Solution
- ✅ **Self-contained** - Everything in the container
- ✅ **Reproducible** - Same environment every time
- ✅ **Isolated** - No conflicts with system packages
- ✅ **Portable** - Works on any system with Docker
- ✅ **Bulletproof** - Pre-tested, pre-configured

---

## 🚀 Quick Start (3 Commands)

### Step 1: Get Ubuntu Server

Launch Ubuntu 22.04 on AWS (same as before)

### Step 2: Upload Deployment Files

```bash
# On your computer
scp -i your-key.pem deploy_docker.sh ubuntu@your-server-ip:~/
```

### Step 3: Run ONE Command

```bash
# On your server
ssh -i your-key.pem ubuntu@your-server-ip
sudo bash deploy_docker.sh
```

**That's it!** 🎉

The script will:
1. Install Docker (if needed)
2. Install Docker Compose (if needed)
3. Build your application image
4. Start everything in a container

---

## 📋 What You Need

### Minimum Requirements
- Ubuntu 22.04 server
- 2GB RAM (4GB recommended)
- 20GB disk space
- Internet connection
- GitHub repository with your code

### What Gets Installed
- **Docker** - Container runtime
- **Docker Compose** - Multi-container orchestrator

**That's all!** Everything else runs inside the container.

---

## 🎯 How It Works

### Architecture

```
┌─────────────────────────────────────────────┐
│           Docker Container                  │
├─────────────────────────────────────────────┤
│                                             │
│  ┌────────────┐  ┌─────────────────────┐   │
│  │  MongoDB   │  │  Supervisor         │   │
│  │  Port 27017│  │  (Process Manager)  │   │
│  └────────────┘  └─────────────────────┘   │
│                                             │
│  ┌────────────┐  ┌────────────┐            │
│  │  Backend   │  │  Frontend  │            │
│  │  FastAPI   │  │  React     │            │
│  │  Port 8001 │  │  Port 3000 │            │
│  └────────────┘  └────────────┘            │
│                                             │
│  ┌────────────────────────────────────┐    │
│  │       Nginx (Port 80)              │    │
│  │       Reverse Proxy                │    │
│  └────────────────────────────────────┘    │
│                                             │
└─────────────────────────────────────────────┘
              ↕
         Your Server Port 80
```

### What's Inside the Container

The container includes:
- Ubuntu 22.04 base
- Python 3.11
- Node.js 20.x + Yarn
- MongoDB 7.0
- Nginx
- Supervisor
- Your application code
- All dependencies

---

## 📝 Step-by-Step Usage

### Full Process

**1. On your local computer:**

```bash
# Make sure you have these files:
deploy_docker.sh
docker-compose.production.yml
Dockerfile.production
docker/
  ├── supervisord-production.conf
  ├── nginx-production.conf
  ├── start.sh
  ├── .env.backend.template
  └── .env.frontend.template

# Upload to server
scp -i key.pem -r deploy_docker.sh docker/ Dockerfile.production docker-compose.production.yml ubuntu@server-ip:~/
```

**2. On your server:**

```bash
ssh -i key.pem ubuntu@server-ip

# Run deployment
sudo bash deploy_docker.sh
```

**3. Answer questions:**

```
GitHub repository URL: https://github.com/yourusername/your-repo
Branch: main
Database: 1
```

**4. Wait for build (5-10 minutes first time)**

You'll see:
```
Building Docker Image
[+] Building 325.4s (23/23) FINISHED
=> [internal] load build definition
=> [stage-0  1/15] FROM docker.io/library/ubuntu:22.04
=> [stage-0  2/15] RUN apt-get update && apt-get install...
...
```

**5. Success!**

```
🎉 SUCCESS! 🎉

  🌐 Application:  http://your-server-ip
  📡 API Docs:     http://your-server-ip/api/docs
```

---

## 🔧 Management Commands

### View Logs

```bash
# All logs
docker compose -f docker-compose.production.yml logs -f

# Specific service
docker compose -f docker-compose.production.yml logs -f app
```

### Restart Services

```bash
docker compose -f docker-compose.production.yml restart
```

### Stop Services

```bash
docker compose -f docker-compose.production.yml down
```

### Start Services

```bash
docker compose -f docker-compose.production.yml up -d
```

### Check Status

```bash
docker compose -f docker-compose.production.yml ps
```

### Access Container Shell

```bash
docker compose -f docker-compose.production.yml exec app bash

# Inside container:
supervisorctl status          # Check services
tail -f /var/log/supervisor/backend.out.log
exit
```

### Update from Git

```bash
# Rebuild with latest code
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml build --no-cache
docker compose -f docker-compose.production.yml up -d
```

---

## 🔄 Update Workflow

### To Deploy Changes

**Method 1: Rebuild Container (Recommended)**

```bash
# Stop current container
docker compose -f docker-compose.production.yml down

# Rebuild with latest code
docker compose -f docker-compose.production.yml build --no-cache

# Start new container
docker compose -f docker-compose.production.yml up -d
```

**Method 2: Git Pull Inside Container**

```bash
# Access container
docker compose -f docker-compose.production.yml exec app bash

# Inside container:
cd /app
git pull
supervisorctl restart all
exit
```

---

## 💾 Data Persistence

### MongoDB Data

Data is stored in a Docker volume:

```bash
# List volumes
docker volume ls

# Backup MongoDB
docker compose -f docker-compose.production.yml exec app mongodump --out /data/backup

# Copy backup out of container
docker cp $(docker compose ps -q app):/data/backup ./mongodb_backup
```

### Logs

Logs are mounted to `./logs` directory:

```bash
# View logs from host
tail -f logs/backend.out.log
tail -f logs/frontend.out.log
```

---

## 🐛 Troubleshooting

### Container Won't Start

```bash
# View logs
docker compose -f docker-compose.production.yml logs

# Check container status
docker compose -f docker-compose.production.yml ps
```

### Build Fails

```bash
# Clean everything and rebuild
docker compose -f docker-compose.production.yml down -v
docker system prune -a
docker compose -f docker-compose.production.yml build --no-cache
```

### Services Not Running

```bash
# Access container
docker compose -f docker-compose.production.yml exec app bash

# Check supervisor
supervisorctl status

# Restart services
supervisorctl restart all

# View logs
tail -f /var/log/supervisor/backend.err.log
```

### Can't Access Application

```bash
# Check if container is running
docker ps

# Check if ports are mapped
docker port $(docker compose ps -q app)

# Test from inside container
docker compose exec app curl http://localhost:80

# Check firewall
sudo ufw status
sudo ufw allow 80/tcp
```

---

## 🔐 Production Considerations

### Security

**1. Don't expose internal ports**

In `docker-compose.production.yml`, remove these for production:

```yaml
ports:
  - "80:80"       # Keep this
  # - "3000:3000"   # Remove - only Nginx should be exposed
  # - "8001:8001"   # Remove - only Nginx should be exposed
  # - "27017:27017" # Remove - MongoDB should be internal only
```

**2. Use secrets for sensitive data**

Don't hardcode in .env files. Use Docker secrets or environment variables.

**3. Enable MongoDB authentication**

Access container and configure:

```bash
docker compose exec app bash
mongosh
use admin
db.createUser({user: "admin", pwd: "password", roles: ["root"]})
exit
```

Update MONGO_URL in .env:
```
MONGO_URL=mongodb://admin:password@localhost:27017
```

Rebuild container.

### Performance

**1. Production build for React**

Modify Dockerfile.production to build React:

```dockerfile
RUN cd /app/frontend && yarn build
```

Configure Nginx to serve static files instead of proxying.

**2. Increase workers**

In `docker/supervisord-production.conf`:

```ini
command=/app/venv/bin/uvicorn server:app --host 0.0.0.0 --port 8001 --workers 4
```

**3. Resource limits**

In `docker-compose.production.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 4G
```

---

## 📊 Comparison

### Docker vs Traditional

| Aspect | Traditional Install | Docker |
|--------|---------------------|--------|
| **Setup Time** | 15 minutes | 10 minutes (first time), 2 minutes (subsequent) |
| **Dependency Issues** | Common | Never |
| **Reproducibility** | Hard | Perfect |
| **Isolation** | None | Complete |
| **Portability** | Poor | Excellent |
| **Updates** | Risky | Safe (rollback easy) |
| **Debugging** | Complex | Easier (logs, shell access) |

---

## 🎓 Advanced Usage

### Custom Configuration

**Build with different repo:**

```bash
GIT_REPO=https://github.com/other/repo \
GIT_BRANCH=develop \
docker compose -f docker-compose.production.yml build
```

**Override environment variables:**

```bash
MONGO_URL=mongodb://atlas-url \
docker compose -f docker-compose.production.yml up -d
```

### Multiple Environments

Create different compose files:

```bash
# Staging
docker-compose.staging.yml

# Production
docker-compose.production.yml

# Development
docker-compose.dev.yml
```

Deploy specific environment:

```bash
docker compose -f docker-compose.staging.yml up -d
```

---

## ✅ Success Checklist

After deployment, verify:

- [ ] Container is running: `docker ps`
- [ ] All services healthy: `docker compose ps`
- [ ] Can access frontend: `http://server-ip`
- [ ] Can access API docs: `http://server-ip/api/docs`
- [ ] Health check passes: `http://server-ip/health`
- [ ] Logs show no errors: `docker compose logs`
- [ ] MongoDB is running: `docker compose exec app mongosh`

---

## 🎉 Why This Is Better

### Advantages

1. **No System Conflicts** - Everything isolated in container
2. **Reproducible** - Same environment every time
3. **Fast Updates** - Just rebuild and restart
4. **Easy Rollback** - Keep old images
5. **Portable** - Move to any system
6. **Scalable** - Easy to run multiple instances
7. **Professional** - Industry standard approach

### When to Use Docker

- ✅ Production deployments
- ✅ Multiple environments (dev, staging, prod)
- ✅ Team development
- ✅ CI/CD pipelines
- ✅ When you want "it just works"

### When Traditional Might Be Better

- 🤔 Learning/educational purposes
- 🤔 Very limited resources (< 1GB RAM)
- 🤔 Need to debug system-level issues

---

## 📞 Getting Help

### Check These First

1. View logs: `docker compose logs`
2. Check status: `docker compose ps`
3. Access shell: `docker compose exec app bash`
4. View this guide

### Common Solutions

**Problem: Build fails**
```bash
docker system prune -a
docker compose build --no-cache
```

**Problem: Container exits immediately**
```bash
docker compose logs
# Check the error and fix .env or Dockerfile
```

**Problem: Can't connect**
```bash
# Check firewall
sudo ufw allow 80/tcp
# Check container ports
docker port $(docker compose ps -q app)
```

---

## 🚀 Quick Reference

```bash
# Deploy
sudo bash deploy_docker.sh

# View logs
docker compose -f docker-compose.production.yml logs -f

# Restart
docker compose -f docker-compose.production.yml restart

# Stop
docker compose -f docker-compose.production.yml down

# Update
docker compose -f docker-compose.production.yml build --no-cache
docker compose -f docker-compose.production.yml up -d

# Shell access
docker compose -f docker-compose.production.yml exec app bash
```

---

**Docker deployment = Bulletproof deployment!** 🐳🚀
