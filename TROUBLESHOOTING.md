# 🔧 Troubleshooting Guide - Installer Issues

## Quick Fix: Installer Freezes

If the installer freezes or hangs, follow these steps:

### Step 1: Stop the Installer

Press `Ctrl+C` to stop the installer.

### Step 2: Clear Package Manager Locks

```bash
# Kill any stuck apt processes
sudo killall apt apt-get 2>/dev/null

# Remove lock files
sudo rm -f /var/lib/apt/lists/lock
sudo rm -f /var/cache/apt/archives/lock
sudo rm -f /var/lib/dpkg/lock*

# Fix any broken packages
sudo dpkg --configure -a
```

### Step 3: Run Test Script

```bash
sudo bash test_installer.sh
```

This will check if your system is ready.

### Step 4: Run Installer Again

```bash
sudo bash auto_deploy.sh
```

---

## Common Issues & Solutions

### Issue 1: Freezes at "Updating System Packages"

**Cause:** Another process is using the package manager, or slow network.

**Solution:**

```bash
# Check what's using apt
sudo lsof /var/lib/dpkg/lock-frontend

# If something is there, wait for it to finish OR kill it
sudo killall apt apt-get

# Clear locks
sudo rm -f /var/lib/dpkg/lock*
sudo dpkg --configure -a

# Try again
sudo bash auto_deploy.sh
```

---

### Issue 2: "Could not get lock" Error

**Cause:** Package manager is locked by another process.

**Solution:**

```bash
# Wait 2 minutes (another update might be running)
# OR force clear:

sudo killall apt apt-get dpkg
sudo rm -f /var/lib/dpkg/lock*
sudo rm -f /var/cache/apt/archives/lock
sudo rm -f /var/lib/apt/lists/lock
sudo dpkg --configure -a

# Reboot if needed
sudo reboot

# After reboot, try again
sudo bash auto_deploy.sh
```

---

### Issue 3: Slow Package Installation

**Cause:** Slow network or server location far from package mirrors.

**Solution:**

Just be patient! The installer now shows progress. Look for:
- "Installing..." messages
- Package names scrolling
- No error messages = it's working

Average times:
- System update: 1-2 minutes
- Python install: 2-3 minutes
- Node.js install: 1-2 minutes
- MongoDB install: 2-3 minutes
- Your packages: 3-5 minutes

**Total: 10-15 minutes is normal**

---

### Issue 4: Connection Timeout

**Cause:** Network issues or firewall blocking.

**Solution:**

```bash
# Test internet connection
ping -c 3 google.com

# Test package repositories
sudo apt-get update

# If network is slow, increase timeout:
# Edit auto_deploy.sh and add to apt commands:
# -o Acquire::http::Timeout="300"
```

---

### Issue 5: Git Clone Fails

**Cause:** Wrong repository URL, private repo, or network issue.

**Solution:**

```bash
# Test git access manually
git clone YOUR_REPO_URL test_clone

# If it asks for credentials, your repo is private
# Use HTTPS with token:
# https://TOKEN@github.com/user/repo.git

# Or use SSH:
# git@github.com:user/repo.git
# (requires SSH key setup)
```

---

### Issue 6: Permission Denied

**Cause:** Not running as root.

**Solution:**

```bash
# Always use sudo
sudo bash auto_deploy.sh

# NOT:
bash auto_deploy.sh  # ✗ Wrong
```

---

### Issue 7: Services Won't Start

**Cause:** Port already in use, or configuration error.

**Solution:**

```bash
# Check what's using ports
sudo lsof -i :3000
sudo lsof -i :8001
sudo lsof -i :27017

# Kill any blocking processes
sudo kill -9 <PID>

# Check supervisor status
sudo supervisorctl status

# Check logs
sudo tail -f /var/log/supervisor/backend.err.log
sudo tail -f /var/log/supervisor/frontend.err.log

# Restart everything
sudo supervisorctl restart all
```

---

## Debugging Steps

### See What's Happening

The installer now shows output! You should see:

```
✓ System updated
✓ Essential tools installed
✓ Python 3.11 installed (Python 3.11.x)
ℹ Installing Node.js...
```

If you don't see these messages, something is wrong.

### Check the Log File

```bash
# Find the log file
ls -lt /var/log/auto_deploy_*.log | head -1

# View the log
sudo tail -f /var/log/auto_deploy_*.log
```

### Manual Testing

Test each component manually:

```bash
# Test Python
python3 --version

# Test Node.js
node --version
yarn --version

# Test MongoDB (if self-hosted)
sudo systemctl status mongod

# Test Nginx
sudo nginx -t
sudo systemctl status nginx
```

---

## Starting Fresh

If everything is messed up, start completely fresh:

### Full Reset

```bash
# Stop all services
sudo supervisorctl stop all
sudo systemctl stop nginx
sudo systemctl stop mongod

# Remove everything
sudo rm -rf /opt/app
sudo rm -f /etc/supervisor/conf.d/app.conf
sudo rm -f /etc/nginx/sites-enabled/app
sudo rm -f /etc/nginx/sites-available/app

# Clear package cache
sudo apt-get clean
sudo apt-get autoclean

# Reboot
sudo reboot

# After reboot, try again
sudo bash auto_deploy.sh
```

---

## System Requirements Check

Before running installer, verify:

```bash
# 1. Ubuntu version
lsb_release -a
# Should show: Ubuntu 22.04

# 2. Available disk space
df -h /
# Should show: at least 5GB free

# 3. Available memory
free -h
# Should show: at least 2GB

# 4. Internet connection
ping -c 3 google.com
# Should work

# 5. Can install packages
sudo apt-get update
# Should complete without errors
```

---

## AWS-Specific Issues

### Security Group Not Configured

**Symptom:** Can SSH but can't access website.

**Solution:**
1. Go to AWS EC2 Console
2. Select your instance
3. Click Security Groups
4. Add inbound rules:
   - Port 80 (HTTP) from 0.0.0.0/0
   - Port 443 (HTTPS) from 0.0.0.0/0

### Instance Too Small

**Symptom:** Installer extremely slow or crashes.

**Solution:**
- Minimum: t2.small (2GB RAM)
- Recommended: t2.medium (4GB RAM)

Upgrade your instance type if needed.

---

## Still Having Issues?

### Collect Debug Information

```bash
# Create debug report
sudo bash -c 'cat > /tmp/debug_report.txt << EOF
===== SYSTEM INFO =====
$(lsb_release -a)

===== DISK SPACE =====
$(df -h)

===== MEMORY =====
$(free -h)

===== NETWORK =====
$(ip addr)
$(ping -c 3 google.com)

===== APT STATUS =====
$(sudo lsof /var/lib/dpkg/lock* 2>&1)

===== PROCESSES =====
$(ps aux | grep -E "apt|dpkg")

===== LAST LOG =====
$(ls -lt /var/log/auto_deploy_*.log | head -1)
$(tail -50 $(ls -t /var/log/auto_deploy_*.log | head -1))
EOF'

# View the report
cat /tmp/debug_report.txt

# Share this when asking for help
```

---

## Prevention Tips

### Before Running Installer:

1. ✅ Fresh Ubuntu 22.04 instance
2. ✅ At least 2GB RAM
3. ✅ At least 10GB disk space
4. ✅ Good internet connection
5. ✅ No other apt processes running
6. ✅ Security groups configured

### Best Practices:

- Run on a fresh server (no other software installed)
- Don't interrupt the installer
- Wait for each step to complete
- Watch for error messages
- Check logs if something fails

---

## Quick Reference Commands

```bash
# Test system readiness
sudo bash test_installer.sh

# Run installer
sudo bash auto_deploy.sh

# Clear apt locks
sudo rm -f /var/lib/dpkg/lock*
sudo dpkg --configure -a

# Check services
sudo supervisorctl status

# View logs
sudo tail -f /var/log/auto_deploy_*.log

# Restart services
sudo supervisorctl restart all

# Check what's using ports
sudo lsof -i :80
sudo lsof -i :3000
sudo lsof -i :8001
```

---

## Success Indicators

You know it's working when you see:

✅ Colored output with progress bars
✅ Messages like "Installing...", "✓ Complete"
✅ Step numbers advancing (1/10, 2/10, etc.)
✅ Package names scrolling
✅ No red "ERROR" messages
✅ Final "SUCCESS!" screen

---

**Remember: The installer is designed to be run multiple times safely!**

**If it fails, just run it again after fixing the issue.** 🔄
