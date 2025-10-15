# 🎯 Usage Instructions - FastAPI + React Deployment Package

## Overview

You now have a complete deployment package ready to use on your Ubuntu 22.04 AWS server. This guide shows you exactly how to use it.

---

## 📦 What You Have

```
/app/fastapi-react-deployment-package.tar.gz  (16 KB)
```

This package contains:
- ✅ Installation scripts for all dependencies
- ✅ Automated deployment system
- ✅ Process management configuration
- ✅ Docker support
- ✅ Management utilities
- ✅ Complete documentation

---

## 🚀 How to Deploy on AWS Ubuntu 22.04

### Step 1: Transfer Package to Server

From your local machine:

```bash
# Upload the package to your AWS server
scp -i your-key.pem fastapi-react-deployment-package.tar.gz ubuntu@your-server-ip:~/

# Example:
scp -i my-aws-key.pem fastapi-react-deployment-package.tar.gz ubuntu@54.123.45.67:~/
```

### Step 2: Connect to Server

```bash
ssh -i your-key.pem ubuntu@your-server-ip
```

### Step 3: Extract and Run

```bash
# Extract the package
tar -xzf fastapi-react-deployment-package.tar.gz
cd fastapi-react-deployment-package

# Make scripts executable (already done, but just in case)
chmod +x *.sh

# Run the interactive setup wizard
sudo ./quick_start.sh
```

### Step 4: Follow the Wizard

The wizard will ask you:

1. **Git Repository URL**: `https://github.com/yourusername/your-repo.git`
2. **Branch Name**: `main` (or your branch)
3. **Database Name**: `app_database` (or your choice)
4. **Backend URL**: Will use server IP automatically

Then it will automatically:
- Install Python 3.11, Node.js 20.x, MongoDB 7.0, Nginx
- Clone your repository
- Configure environment variables
- Setup process management
- Deploy and start your application

### Step 5: Access Your Application

```
Frontend:   http://your-server-ip
Backend:    http://your-server-ip/api/
API Docs:   http://your-server-ip/api/docs
```

---

## 🔄 Updating Your Application

After making changes to your code and pushing to git:

```bash
# SSH into server
ssh -i your-key.pem ubuntu@your-server-ip

# Navigate to app directory
cd /opt/app

# Run deployment script
sudo -E ./deploy.sh
```

The script will:
1. Create a backup
2. Pull latest code
3. Install dependencies
4. Restart services
5. Verify health
6. Rollback if anything fails

---

## 🛠️ Management Commands

### Check Application Health

```bash
cd /opt/app
./health_check.sh
```

### View Logs

```bash
# Backend logs (follow in real-time)
./logs.sh backend -f

# Frontend logs
./logs.sh frontend -f

# Error logs only
./logs.sh backend -e

# All logs
./logs.sh all
```

### Manage Services

```bash
# Check status
sudo supervisorctl status

# Restart all services
sudo supervisorctl restart app:*

# Restart specific service
sudo supervisorctl restart backend
sudo supervisorctl restart frontend

# Stop services
sudo supervisorctl stop app:*

# Start services
sudo supervisorctl start app:*
```

---

## 🐳 Alternative: Docker Deployment

If you prefer Docker:

### Step 1: Install Docker on Server

```bash
ssh -i your-key.pem ubuntu@your-server-ip

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Step 2: Deploy with Docker

```bash
# Clone your repository
git clone https://github.com/yourusername/your-repo.git
cd your-repo

# Copy deployment files
# (if not already in your repo)

# Configure environment
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env

# Edit as needed
nano backend/.env
nano frontend/.env

# Start with Docker
docker-compose up -d

# View logs
docker-compose logs -f

# Check status
docker-compose ps
```

---

## 📚 Documentation Guide

Inside the package, you'll find:

1. **DEPLOYMENT_PACKAGE_README.md** - Start here for quick overview
2. **AWS_SETUP_GUIDE.md** - Complete AWS EC2 setup guide
3. **README_DEPLOYMENT.md** - Detailed deployment documentation
4. **DEPLOYMENT_INDEX.md** - Complete index of all features

Open with:
```bash
less DEPLOYMENT_PACKAGE_README.md
```

Or copy to your local machine to read:
```bash
scp -i your-key.pem ubuntu@your-server-ip:~/fastapi-react-deployment-package/DEPLOYMENT_PACKAGE_README.md .
```

---

## 🎯 Quick Start Summary

The absolute fastest way to deploy:

```bash
# 1. On local machine
scp -i key.pem fastapi-react-deployment-package.tar.gz ubuntu@server-ip:~/

# 2. On server
ssh -i key.pem ubuntu@server-ip
tar -xzf fastapi-react-deployment-package.tar.gz
cd fastapi-react-deployment-package
sudo ./quick_start.sh

# 3. Access application
# Open browser: http://server-ip
```

That's it! The wizard handles everything else.

---

## 🔧 Troubleshooting

### Issue: Can't connect to server

```bash
# Check security group allows SSH
# Verify key permissions
chmod 400 your-key.pem

# Use correct username (ubuntu, not root)
ssh -i your-key.pem ubuntu@server-ip
```

### Issue: Services not starting

```bash
cd /opt/app
./health_check.sh
./logs.sh backend -e
sudo supervisorctl status
```

### Issue: Application not accessible

```bash
# Check services are running
sudo supervisorctl status

# Check ports
sudo lsof -i :80
sudo lsof -i :8001
sudo lsof -i :3000

# Check firewall
sudo ufw status
```

### Get More Help

All scripts have built-in error handling and logging. Check:

1. Run health check: `./health_check.sh`
2. View logs: `./logs.sh all`
3. Read docs: `less AWS_SETUP_GUIDE.md`

---

## 📋 Pre-Deployment Checklist

Before running the installer:

- [ ] Ubuntu 22.04 EC2 instance launched
- [ ] SSH access working
- [ ] Security group allows ports 22, 80, 443
- [ ] Git repository ready
- [ ] Have repository URL handy
- [ ] (Optional) Domain name configured

---

## 🎉 What Happens During Installation

The `quick_start.sh` wizard will:

1. **Install System Dependencies** (5-10 min)
   - Python 3.11
   - Node.js 20.x + Yarn
   - MongoDB 7.0
   - Nginx
   - Supervisor

2. **Clone Repository** (1-2 min)
   - Clones to /opt/app
   - Checks out specified branch

3. **Configure Environment** (1 min)
   - Creates .env files
   - Configures database
   - Sets up backend URL

4. **Setup Services** (2-3 min)
   - Configures Supervisor
   - Sets up Nginx proxy
   - Creates systemd services

5. **Deploy Application** (3-5 min)
   - Creates Python virtual environment
   - Installs Python dependencies
   - Installs Node.js dependencies
   - Starts all services

6. **Verify Deployment** (1 min)
   - Runs health checks
   - Verifies all services
   - Shows access URLs

**Total time: 15-20 minutes**

---

## 🔑 Important Paths

After installation:

```
Application Root:     /opt/app
Backend:             /opt/app/backend
Frontend:            /opt/app/frontend
Python Venv:         /opt/app/venv
Logs:                /var/log/supervisor/
Backups:             /opt/app_backups/
Nginx Config:        /etc/nginx/sites-available/app
Supervisor Config:   /etc/supervisor/conf.d/app.conf
```

---

## 📞 Support Resources

### In Package Documentation
- Quick Start: `DEPLOYMENT_PACKAGE_README.md`
- AWS Guide: `AWS_SETUP_GUIDE.md`
- Full Docs: `README_DEPLOYMENT.md`
- Index: `DEPLOYMENT_INDEX.md`

### Built-in Tools
- Health Check: `./health_check.sh`
- Log Viewer: `./logs.sh`
- Deployment: `./deploy.sh`

### Online Resources
- FastAPI Docs: https://fastapi.tiangolo.com/
- React Docs: https://react.dev/
- MongoDB Docs: https://docs.mongodb.com/
- Nginx Docs: https://nginx.org/en/docs/

---

## ✅ Success Indicators

Your deployment is successful when:

1. ✅ `sudo supervisorctl status` shows all services RUNNING
2. ✅ `curl http://localhost/api/` returns response
3. ✅ Browser loads `http://your-server-ip`
4. ✅ `./health_check.sh` all checks pass
5. ✅ No errors in `./logs.sh all`

---

## 🚀 Next Steps After Successful Deployment

### Immediate (First Day)
1. Test all application features
2. Verify data persistence (create, read, update, delete)
3. Check logs for any errors
4. Save connection details

### Short Term (First Week)
1. Configure custom domain name
2. Setup SSL/TLS certificate
3. Enable MongoDB authentication
4. Configure firewall properly
5. Test deployment workflow

### Long Term (First Month)
1. Setup automated backups
2. Configure monitoring
3. Optimize performance
4. Document custom changes
5. Plan scaling strategy

---

## 💡 Pro Tips

### Development
- Access services directly on ports 3000 and 8001 for debugging
- Hot reload is enabled by default (no restart needed for code changes)
- Use `./logs.sh backend -f` to watch logs in real-time

### Production
- Use a custom domain instead of IP address
- Enable SSL with Let's Encrypt (free)
- Restrict firewall to only necessary ports
- Enable MongoDB authentication
- Setup regular backups
- Monitor application health

### Operations
- Keep the deployment package for future servers
- Document any custom configurations
- Test the rollback feature before you need it
- Practice deployments on staging first

---

## 📊 Resource Requirements

### Minimum (Testing)
- Instance: t2.small
- RAM: 2 GB
- Storage: 10 GB
- Cost: ~$17/month

### Recommended (Production)
- Instance: t2.medium or t3.medium
- RAM: 4 GB
- Storage: 20-30 GB
- Cost: ~$35-50/month

### High Traffic
- Instance: t3.large or c5.large
- RAM: 8 GB+
- Storage: 50 GB+
- Consider: Load balancer, multiple instances

---

## 🎯 Final Checklist

Ready to deploy? Verify:

- [ ] Package downloaded/extracted
- [ ] Have AWS server access
- [ ] Git repository URL ready
- [ ] Read quick start guide
- [ ] Know where to find logs
- [ ] Understand how to update
- [ ] Have troubleshooting steps handy

**You're ready to deploy! Run `sudo ./quick_start.sh`**

---

## 🎉 Congratulations!

You now have everything needed to deploy your FastAPI + React application on AWS Ubuntu 22.04 with:

- ✅ Automated installation
- ✅ Easy deployment
- ✅ Process management
- ✅ Health monitoring
- ✅ Log management
- ✅ Backup system
- ✅ Docker support
- ✅ Production ready

**Happy Deploying! 🚀**
