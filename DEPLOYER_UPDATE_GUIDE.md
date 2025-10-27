# 🔄 Deployer Self-Update Guide

## Overview

Update the **deployer scripts themselves** from git, then optionally rebuild deployed applications with the updated deployer.

---

## 🚀 Quick Start

```bash
sudo bash /app/update_deployer.sh
```

---

## 📋 What It Does

### Step 1: Updates Deployer Scripts
- Pulls latest deployer code from git
- Shows what changed
- Updates all deployment scripts

### Step 2: Scans for Deployments
- Finds all applications deployed on the system
- Shows their current status
- Excludes the deployer directory itself

### Step 3: Rebuilds Deployments (Optional)
- Pulls latest code for selected apps
- Updates dependencies
- Restarts services

---

## 🎯 Use Cases

### Use Case 1: Update Deployer Only
```bash
$ sudo bash /app/update_deployer.sh

Current Deployer Status:
  📂 Location: /app
  🌿 Branch: main
  📝 Commit: a1b2c3d

New commits:
- b4e5f6g Fixed auction deployer bug
- c7d8e9f Added new features

❓ Pull these updates? (Y/N) Y
✓ Deployer updated successfully

❓ Would you like to rebuild any deployments? (Y/N) N

✓ All Updates Complete!
```

### Use Case 2: Update Deployer + Rebuild All Sites
```bash
$ sudo bash /app/update_deployer.sh

[Deployer updates...]

Found 3 deployment(s):
[1] /opt/auction-site
[2] /var/www/blog
[3] /srv/test-app

❓ Would you like to rebuild any deployments? (Y/N) Y

Select deployment(s) to rebuild:
  a) All deployments
  s) Select specific deployment(s)
  n) None

Your choice: a

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Rebuilding: /opt/auction-site
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ Pulling latest code...
ℹ Updating backend dependencies...
ℹ Updating frontend dependencies...
ℹ Restarting services...
✓ Rebuild complete

[Repeats for all deployments]

✓ All Updates Complete!
```

### Use Case 3: Update Deployer + Select Specific Sites
```bash
❓ Would you like to rebuild any deployments? (Y/N) Y

Select deployment(s) to rebuild:
  a) All deployments
  s) Select specific deployment(s)
  n) None

Your choice: s

Enter deployment numbers (e.g., 1 3 5): 1 3

[Rebuilds only deployments 1 and 3]
```

---

## 🔍 How It Works

### Deployer Update Process

1. **Check Git Status**
   - Verifies deployer is a git repository
   - Shows current branch and commit
   - Checks for uncommitted changes

2. **Fetch Updates**
   - Fetches from origin
   - Compares local vs remote
   - Shows new commits available

3. **Pull Changes**
   - Pulls latest deployer scripts
   - Shows files that changed
   - Updates all deployment tools

### Deployment Scanning

Scans these locations:
- `/opt/*`
- `/var/www/*`
- `/home/*/app`
- `/srv/*`
- Supervisor configs

Looks for directories with:
- ✅ `backend/` folder
- ✅ `frontend/` folder
- ❌ Not the deployer directory itself

### Rebuild Process

For each selected deployment:

1. **Git Pull** (if git repo)
   ```bash
   cd /opt/auction-site
   git pull
   ```

2. **Update Backend**
   ```bash
   cd backend
   pip3 install -r requirements.txt --upgrade
   ```

3. **Update Frontend**
   ```bash
   cd frontend
   yarn install  # or npm install
   ```

4. **Restart Services**
   ```bash
   supervisorctl restart auction-site-backend
   supervisorctl restart auction-site-frontend
   ```

---

## 📊 Workflow Examples

### Daily Workflow: Update Deployer Scripts

```bash
# On your dev machine - update deployer repo
cd ~/deployer-scripts
git add .
git commit -m "Updated auction deployer"
git push origin main

# On server - update deployer
ssh ubuntu@server
sudo bash /app/update_deployer.sh

# Choose: Update deployer only (no rebuild)
```

### Weekly Workflow: Update Everything

```bash
# Update deployer scripts (as above)

# On server - update deployer AND all sites
sudo bash /app/update_deployer.sh

# Choose: Update deployer + rebuild all deployments
```

### Deployment Workflow: New Deployer Features

```bash
# After adding new features to deployer

# 1. Update deployer on server
sudo bash /app/update_deployer.sh

# 2. Deploy NEW site with updated deployer
sudo bash /app/auto_deploy_auction.sh

# New deployment uses latest deployer version
```

---

## 🛡️ Safety Features

### Uncommitted Changes
```bash
⚠ You have uncommitted changes in the deployer

 M auto_deploy.sh
 M update_deployer.sh

❓ Stash these changes before updating? (Y/N) Y

✓ Changes stashed
```

Changes saved as:
```bash
git stash list
# stash@{0}: Auto-stash before deployer update 20250127_140523
```

To restore later:
```bash
cd /app
git stash pop
```

### No Remote Configured
```bash
✗ Deployer directory is not a git repository

To use this script, the deployer must be in a git repository.
Initialize git in /app or clone from a repository.
```

### Already Up to Date
```bash
✓ Deployer is already up to date

❓ Would you like to rebuild any deployments? (Y/N)
```

---

## 📂 File Structure

### Deployer Repository (e.g., /app)
```
/app/                              # Deployer scripts
├── .git/                         # Git repository
├── update_deployer.sh            # This script
├── auto_deploy.sh                # Basic deployer
├── auto_deploy_auction.sh        # Auction deployer
└── [other deployment scripts]
```

### Deployed Applications (e.g., /opt/auction)
```
/opt/auction/                     # Deployed application
├── .git/                         # App's git repo
├── backend/
├── frontend/
└── [application code]
```

**Important:** Deployer and deployments can be separate git repositories!

---

## 🔧 Troubleshooting

### Issue: "Not a git repository"

**Solution:**
```bash
cd /app
git init
git remote add origin https://github.com/you/deployer-scripts.git
git fetch origin
git branch --set-upstream-to=origin/main main
```

### Issue: Stash conflicts

**Solution:**
```bash
cd /app
git stash drop  # Remove problematic stash
# Or
git stash apply stash@{1}  # Apply specific stash
```

### Issue: Can't pull from remote

**Solution:**
```bash
cd /app
git remote -v  # Check remote URL

# If SSH key issue
ssh -T git@github.com

# If authentication issue (use token)
git remote set-url origin https://YOUR_TOKEN@github.com/user/repo.git
```

### Issue: Rebuild fails

**Solution:**
Check individual deployment:
```bash
cd /opt/auction-site
git status
pip3 install -r backend/requirements.txt
cd frontend && yarn install
supervisorctl status
```

---

## 📝 Best Practices

### ✅ DO

1. **Commit deployer changes** before updating:
   ```bash
   cd ~/deployer-scripts
   git add .
   git commit -m "Updated deployer"
   git push
   ```

2. **Test deployer locally first**:
   ```bash
   bash auto_deploy_auction.sh --dry-run  # If supported
   ```

3. **Update deployer regularly**:
   ```bash
   # Weekly schedule
   sudo bash /app/update_deployer.sh
   ```

4. **Review changes** before pulling:
   ```bash
   git log --oneline HEAD..@{u}
   git diff HEAD..@{u}
   ```

### ❌ DON'T

1. Don't modify deployer scripts directly on server
2. Don't skip uncommitted change warnings
3. Don't rebuild all sites without testing one first
4. Don't forget to backup before major updates

---

## 🎯 Integration with Other Scripts

### Works With

- ✅ `auto_deploy.sh` - Uses updated deployer for new deployments
- ✅ `auto_deploy_auction.sh` - Uses updated auction deployer
- ✅ All other deployment scripts in the repository

### Independent Of

- Deployed application updates (those have their own git repos)
- Service management (supervisor handles services)
- Database updates (not affected by deployer updates)

---

## 🚀 Quick Commands

```bash
# Update deployer only
sudo bash /app/update_deployer.sh

# View deployer status
cd /app && git status && git log --oneline -5

# Check deployed sites
sudo supervisorctl status

# Manually rebuild one site
cd /opt/auction-site
git pull
cd backend && pip3 install -r requirements.txt
cd ../frontend && yarn install
sudo supervisorctl restart auction-site-backend auction-site-frontend
```

---

## 📞 Summary

**What:** Update deployer scripts from git + optionally rebuild sites

**When:** After pushing deployer changes to git

**How:** `sudo bash /app/update_deployer.sh`

**Result:**
- ✅ Latest deployer scripts
- ✅ All sites can use updated deployer
- ✅ Optional: Existing sites rebuilt with updates

---

**Happy Deploying! 🎉**
