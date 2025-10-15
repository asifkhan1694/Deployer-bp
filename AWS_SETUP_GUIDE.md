# AWS EC2 Ubuntu 22.04 Setup Guide for FastAPI + React

Complete guide for deploying your FastAPI + React application on AWS EC2 with Ubuntu 22.04.

## 🎯 Overview

This guide will help you:
1. Launch an Ubuntu 22.04 EC2 instance on AWS
2. Deploy your FastAPI + React application
3. Configure for production use
4. Enable git pull and smooth deployments

## 📋 Prerequisites

- AWS Account
- SSH key pair for EC2 access
- Git repository with your application code
- Basic knowledge of SSH and terminal commands

---

## Part 1: AWS EC2 Setup

### Step 1: Launch EC2 Instance

1. **Login to AWS Console**
   - Go to https://console.aws.amazon.com/
   - Navigate to EC2 Dashboard

2. **Launch Instance**
   - Click "Launch Instance"
   - Name: `fastapi-react-app` (or your preferred name)

3. **Choose AMI**
   - Select: **Ubuntu Server 22.04 LTS (HVM), SSD Volume Type**
   - AMI: `ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20250822`
   - Architecture: 64-bit (x86)

4. **Choose Instance Type**
   - Recommended: `t2.medium` (4 GB RAM, 2 vCPUs)
   - Minimum: `t2.small` (2 GB RAM, 1 vCPU) for testing
   - For production: `t3.medium` or higher

5. **Key Pair**
   - Select existing key pair or create new one
   - Download and save the `.pem` file securely
   - On macOS/Linux: `chmod 400 your-key.pem`

6. **Network Settings**
   - Create new security group or use existing
   - Configure Security Group Rules:

   ```
   Type              Protocol    Port Range    Source
   SSH               TCP         22           0.0.0.0/0 (or your IP)
   HTTP              TCP         80           0.0.0.0/0
   HTTPS             TCP         443          0.0.0.0/0
   Custom TCP        TCP         3000         0.0.0.0/0 (optional, dev only)
   Custom TCP        TCP         8001         0.0.0.0/0 (optional, dev only)
   ```

7. **Configure Storage**
   - Size: 20 GB minimum, 30 GB recommended
   - Volume Type: General Purpose SSD (gp3)

8. **Advanced Details** (Optional)
   - Enable termination protection for production
   - Add IAM role if needed for AWS services

9. **Launch Instance**
   - Click "Launch Instance"
   - Wait for instance state to be "Running"
   - Note down the Public IPv4 address

### Step 2: Connect to Instance

```bash
# Set correct permissions for key file
chmod 400 your-key.pem

# Connect via SSH
ssh -i your-key.pem ubuntu@<your-instance-public-ip>

# Example:
# ssh -i my-key.pem ubuntu@54.123.45.67
```

On first connection, type `yes` to accept the host key.

---

## Part 2: Application Deployment

### Method A: Quick Start (Recommended)

**1. Upload Deployment Package**

From your local machine:

```bash
# Upload the deployment package
scp -i your-key.pem fastapi-react-deployment-package.tar.gz ubuntu@<instance-ip>:~/

# Example:
# scp -i my-key.pem fastapi-react-deployment-package.tar.gz ubuntu@54.123.45.67:~/
```

**2. SSH into Server and Extract**

```bash
ssh -i your-key.pem ubuntu@<instance-ip>

# Extract package
tar -xzf fastapi-react-deployment-package.tar.gz
cd fastapi-react-deployment-package
```

**3. Run Quick Start Wizard**

```bash
sudo ./quick_start.sh
```

Follow the prompts:
- Enter your Git repository URL
- Enter branch name (default: main)
- Configure database name
- Set backend URL

The wizard will automatically:
- ✅ Install all dependencies (Python, Node.js, MongoDB, Nginx)
- ✅ Clone your repository
- ✅ Configure environment variables
- ✅ Setup process management with Supervisor
- ✅ Deploy and start your application

**4. Verify Installation**

```bash
# Check health
./health_check.sh

# View logs
./logs.sh all

# Check services
sudo supervisorctl status
```

Access your application:
- **Frontend**: http://\<your-instance-ip\>
- **Backend API**: http://\<your-instance-ip\>/api/
- **API Docs**: http://\<your-instance-ip\>/api/docs

---

### Method B: Manual Step-by-Step

If you prefer manual control:

**1. Connect to Server**

```bash
ssh -i your-key.pem ubuntu@<instance-ip>
```

**2. Download Deployment Package**

```bash
# Option 1: Upload from local machine (see Method A)

# Option 2: Clone from your repository
git clone https://github.com/yourusername/your-repo.git
cd your-repo
```

**3. Install System Dependencies**

```bash
sudo chmod +x install.sh
sudo ./install.sh
```

Wait 5-10 minutes for installation to complete.

**4. Configure Environment**

```bash
# Create .env file
cp .env.example .env
nano .env
```

Set these variables:

```bash
GIT_REPO=https://github.com/yourusername/your-repo.git
GIT_BRANCH=main
APP_DIR=/opt/app
VENV_PATH=/opt/app/venv
APP_USER=appuser
```

**5. Clone Your Application**

```bash
sudo mkdir -p /opt/app
sudo git clone $GIT_REPO /opt/app
cd /opt/app
```

**6. Configure Application Environment**

Backend `.env`:

```bash
sudo nano /opt/app/backend/.env
```

```bash
MONGO_URL=mongodb://localhost:27017
DB_NAME=app_database
CORS_ORIGINS=*
```

Frontend `.env`:

```bash
sudo nano /opt/app/frontend/.env
```

```bash
REACT_APP_BACKEND_URL=http://<your-instance-ip>:8001
PORT=3000
```

**7. Setup Supervisor**

```bash
cd /opt/app
sudo ./setup_supervisor.sh
```

**8. Deploy Application**

```bash
sudo -E ./deploy.sh
```

---

## Part 3: Production Configuration

### Domain Name Setup

**1. Point Domain to EC2**

In your DNS provider (GoDaddy, Namecheap, Route53, etc.):

```
Type    Name    Value
A       @       <your-ec2-ip>
A       www     <your-ec2-ip>
```

**2. Update Environment Variables**

```bash
sudo nano /opt/app/frontend/.env
```

Change:
```bash
REACT_APP_BACKEND_URL=https://api.yourdomain.com
```

**3. Configure Nginx for Domain**

```bash
sudo nano /etc/nginx/sites-available/app
```

Change `server_name`:
```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    # ... rest of config
}
```

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### SSL/TLS Setup (HTTPS)

**1. Install Certbot**

```bash
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx
```

**2. Obtain SSL Certificate**

```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

Follow the prompts:
- Enter email address
- Agree to terms
- Choose redirect option (2 - Redirect HTTP to HTTPS)

**3. Test Auto-Renewal**

```bash
sudo certbot renew --dry-run
```

Certificate will auto-renew before expiration.

### MongoDB Security

**1. Enable Authentication**

```bash
mongosh
```

```javascript
use admin
db.createUser({
  user: "admin",
  pwd: "STRONG_PASSWORD_HERE",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" } ]
})

use app_database
db.createUser({
  user: "appuser",
  pwd: "STRONG_PASSWORD_HERE",
  roles: [ { role: "readWrite", db: "app_database" } ]
})

exit
```

**2. Enable Auth in MongoDB Config**

```bash
sudo nano /etc/mongod.conf
```

Add:
```yaml
security:
  authorization: enabled
```

```bash
sudo systemctl restart mongod
```

**3. Update Backend .env**

```bash
sudo nano /opt/app/backend/.env
```

```bash
MONGO_URL=mongodb://appuser:STRONG_PASSWORD_HERE@localhost:27017/app_database
```

**4. Restart Backend**

```bash
sudo supervisorctl restart backend
```

### Firewall Configuration

```bash
# Enable firewall
sudo ufw enable

# Allow SSH (IMPORTANT: Do this first!)
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Remove development ports (optional)
sudo ufw delete allow 3000/tcp
sudo ufw delete allow 8001/tcp

# Check status
sudo ufw status
```

---

## Part 4: Operations & Maintenance

### Continuous Deployment

**Pull and Deploy Updates:**

```bash
cd /opt/app
sudo -E ./deploy.sh
```

The script automatically:
- Creates backup
- Pulls latest code
- Installs dependencies
- Restarts services
- Validates health
- Rolls back on failure

### Monitoring

**Check Application Health:**

```bash
cd /opt/app
./health_check.sh
```

**View Logs:**

```bash
# Backend logs (follow)
./logs.sh backend -f

# Frontend logs
./logs.sh frontend -f

# View errors only
./logs.sh backend -e

# All logs
./logs.sh all
```

**Service Status:**

```bash
sudo supervisorctl status
```

### Backup Strategy

**Automated Backup Script:**

```bash
sudo nano /opt/scripts/backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup MongoDB
mongodump --db app_database --out $BACKUP_DIR

# Backup application
tar -czf $BACKUP_DIR/app.tar.gz /opt/app

# Keep only last 7 backups
find /backup -type d -mtime +7 -exec rm -rf {} +

echo "Backup completed: $BACKUP_DIR"
```

```bash
sudo chmod +x /opt/scripts/backup.sh
```

**Schedule with Cron:**

```bash
sudo crontab -e
```

Add:
```bash
# Backup daily at 2 AM
0 2 * * * /opt/scripts/backup.sh >> /var/log/backup.log 2>&1
```

### Performance Monitoring

**Install monitoring tools:**

```bash
# htop for process monitoring
sudo apt-get install htop

# iotop for disk I/O
sudo apt-get install iotop

# Monitor resources
htop
iotop
df -h
free -h
```

---

## Part 5: Troubleshooting

### Common Issues

**1. Can't SSH into Instance**

```bash
# Check security group allows SSH from your IP
# Verify key file permissions
chmod 400 your-key.pem

# Use correct username
ssh -i your-key.pem ubuntu@<ip>  # NOT root or ec2-user
```

**2. Services Not Starting**

```bash
# Check logs
cd /opt/app
./logs.sh backend -e
./logs.sh frontend -e

# Check supervisor
sudo supervisorctl status
sudo supervisorctl restart app:*

# Check MongoDB
sudo systemctl status mongod
sudo systemctl restart mongod
```

**3. Port Already in Use**

```bash
# Find process using port
sudo lsof -i :8001
sudo lsof -i :3000

# Kill process
sudo kill -9 <PID>

# Restart services
sudo supervisorctl restart app:*
```

**4. Database Connection Failed**

```bash
# Check MongoDB status
sudo systemctl status mongod

# Check connection
mongosh mongodb://localhost:27017

# View MongoDB logs
tail -f /var/log/mongodb/mongod.log

# Restart MongoDB
sudo systemctl restart mongod
```

**5. Nginx 502 Bad Gateway**

```bash
# Check backend is running
curl http://localhost:8001/api/

# Check Nginx error logs
tail -f /var/log/nginx/error.log

# Restart services
sudo supervisorctl restart backend
sudo systemctl restart nginx
```

### Getting Help

**Check all components:**

```bash
cd /opt/app
./health_check.sh
```

**View system resources:**

```bash
# CPU and memory
htop

# Disk space
df -h

# Processes
ps aux | grep -E 'node|python|mongod'
```

---

## 🎯 Success Checklist

After deployment, verify:

- [ ] EC2 instance is running
- [ ] Can SSH into instance
- [ ] All dependencies installed (Python, Node.js, MongoDB)
- [ ] Application cloned to /opt/app
- [ ] Environment variables configured
- [ ] Supervisor managing services
- [ ] Backend API responding: http://\<ip\>/api/
- [ ] Frontend accessible: http://\<ip\>
- [ ] MongoDB connection working
- [ ] Health checks passing
- [ ] Nginx reverse proxy working
- [ ] (Optional) SSL certificate installed
- [ ] (Optional) Domain name configured
- [ ] (Optional) Firewall configured
- [ ] (Optional) Backups scheduled

---

## 📚 Quick Reference

### Essential Commands

```bash
# Deploy updates
cd /opt/app && sudo -E ./deploy.sh

# Check health
cd /opt/app && ./health_check.sh

# View logs
cd /opt/app && ./logs.sh backend -f

# Restart services
sudo supervisorctl restart app:*

# Check status
sudo supervisorctl status

# MongoDB shell
mongosh
```

### Important Paths

```
Application:     /opt/app
Backend:         /opt/app/backend
Frontend:        /opt/app/frontend
Virtual Env:     /opt/app/venv
Logs:            /var/log/supervisor/
Backups:         /opt/app_backups/
Nginx Config:    /etc/nginx/sites-available/app
Supervisor:      /etc/supervisor/conf.d/app.conf
```

### Service URLs

```
Frontend:        http://<your-ip>
Backend API:     http://<your-ip>/api/
API Docs:        http://<your-ip>/api/docs
Health Check:    http://<your-ip>/health
```

---

## 🚀 Next Steps

1. ✅ Complete basic deployment
2. ⚙️ Configure custom domain
3. 🔒 Setup SSL/TLS
4. 🛡️ Harden security (firewall, MongoDB auth)
5. 📊 Setup monitoring
6. 💾 Configure backups
7. 🔄 Test deployment workflow
8. 📱 Add CI/CD pipeline (optional)

---

## 📞 Support

If you encounter issues:

1. Check logs: `./logs.sh all`
2. Run health check: `./health_check.sh`
3. Review error messages
4. Check AWS security groups
5. Verify environment variables
6. Ensure sufficient disk space: `df -h`

**Happy Deploying! 🎉**
