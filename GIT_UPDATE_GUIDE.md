# 🔄 Git Repository Update & Management Guide

Complete guide for updating your deployment, switching repositories, and managing backups.

---

## 📚 Table of Contents

1. [Quick Reference](#quick-reference)
2. [Update from Current Repository](#update-from-current-repository)
3. [Switch to New Repository](#switch-to-new-repository)
4. [Rollback to Previous Version](#rollback-to-previous-version)
5. [Backup Management](#backup-management)
6. [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Reference

### Three Update Scripts Available

| Script | Purpose | Time | Use When |
|--------|---------|------|----------|
| `quick_update.sh` | Fast git pull & restart | 1-2 min | Quick code updates |
| `update_deployment.sh` | Interactive full update | 3-5 min | Major updates, dependencies changed |
| `rollback_deployment.sh` | Restore previous version | 2-3 min | Something went wrong |

### Common Commands

```bash
# Quick update (most common)
sudo bash quick_update.sh

# Full update with options
sudo bash update_deployment.sh

# Switch to different repository
sudo bash update_deployment.sh --new-repo

# Rollback to previous version
sudo bash rollback_deployment.sh
```

---

## 1️⃣ Update from Current Repository

### Option A: Quick Update (Recommended for small changes)

**Use when:** You just pushed code changes to your current repository.

```bash
cd /app
sudo bash quick_update.sh
```

**What it does:**
- ✅ Pulls latest code from git
- ✅ Updates Python dependencies
- ✅ Updates Node.js dependencies  
- ✅ Restarts all services
- ✅ Shows service status

**Time:** 1-2 minutes

---

### Option B: Interactive Update (For major changes)

**Use when:** You want control over each step or made major changes.

```bash
cd /app
sudo bash update_deployment.sh
```

**Interactive prompts:**

1. **Choose action:**
   ```
   1) Update from current repository (git pull)
   2) Switch to a new repository
   3) Exit
   ```
   → Choose `1` for regular update

2. **Create backup?** (Y/N)
   - Y = Creates backup before updating (recommended)
   - N = Skip backup (faster)

3. **Update dependencies?** (Y/N)
   - Y = Reinstalls Python/Node packages (recommended if requirements changed)
   - N = Skip dependency update (faster)

4. **Run database migrations?** (Y/N)
   - Y = Runs seed/migration scripts
   - N = Skip database updates

5. **Restart services?** (Y/N)
   - Y = Restarts backend/frontend (required for changes to take effect)
   - N = Manual restart later

6. **Show logs?** (Y/N)
   - Y = Displays recent error logs
   - N = Skip logs

**Example session:**
```bash
$ sudo bash update_deployment.sh

Current Deployment Status:

  📂 Location:    /app
  🔗 Repository:  https://github.com/user/ballypatrick-auctions.git
  🌿 Branch:      main
  📝 Commit:      a1b2c3d - Updated collections page

What would you like to do?

  1) Update from current repository (git pull)
  2) Switch to a new repository
  3) Exit

Choose option (1-3): 1

❓ Create backup before updating?
   (Y/N, Default: Y)
   Your answer: Y

✓ Backup created at: /app_backups/backup_20250127_103045

ℹ Updating from GitHub...
ℹ Current branch: main
ℹ Current commit: a1b2c3d

ℹ Pulling latest changes...
From https://github.com/user/ballypatrick-auctions
   a1b2c3d..b4e5f6g  main -> origin/main
Updating a1b2c3d..b4e5f6g
Fast-forward
 frontend/src/pages/CollectionsPage.jsx | 25 +++++++++++++++++++------
 backend/routes/collections_routes.py   | 10 +++++-----
 2 files changed, 24 insertions(+), 11 deletions(-)

✓ Updated to commit: b4e5f6g

❓ Update dependencies?
   (Y/N, Default: Y)
   Your answer: Y

ℹ Updating Python dependencies...
✓ Python dependencies updated

ℹ Updating frontend dependencies...
✓ Frontend dependencies updated

❓ Run database migrations/seed scripts?
   (Y/N, Default: N)
   Your answer: N

❓ Restart services now?
   (Y/N, Default: Y)
   Your answer: Y

ℹ Restarting services...
auction-backend: started
auction-frontend: started
✓ Services restarted

ℹ Running health checks...
✓ Backend API is responding
✓ Frontend is responding

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Update Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  📝 Current commit: b4e5f6g
  🌿 Current branch: main

🎉 All done!
```

---

## 2️⃣ Switch to New Repository

### When to Use

- Deploying a completely different application
- Moving from development to production repository
- Switching between project forks

### Method 1: Command Line Flag

```bash
sudo bash update_deployment.sh --new-repo
```

### Method 2: Interactive Menu

```bash
sudo bash update_deployment.sh
# Then select option 2 when prompted
```

### Step-by-Step Process

1. **Provide new repository details:**
   ```
   Enter new GitHub repository URL: https://github.com/user/new-auction-app.git
   Enter branch name (default: main): production
   ```

2. **Confirm the switch:**
   ```
   ℹ New repository: https://github.com/user/new-auction-app.git
   ℹ Branch: production

   ❓ Confirm switch to new repository?
      (Y/N, Default: N)
      Your answer: Y
   ```

3. **Automatic backup created** (cannot be skipped for safety)

4. **Old code removed and new code cloned**

5. **Post-switch tasks:**
   ```
   ⚠ New repository detected - you may need to:
     1. Update environment variables in /app/backend/.env
     2. Update environment variables in /app/frontend/.env
     3. Run seed scripts manually
     4. Update supervisor configuration if ports changed
   ```

### Important: After Repository Switch

#### Check and Update Environment Files

**Backend (.env):**
```bash
cd /app/backend
nano .env
```

Verify/update:
```bash
MONGO_URL=mongodb://localhost:27017
DB_NAME=your_database_name
JWT_SECRET=<generate new secret>
OPENAI_API_KEY=<your key if needed>
ANTHROPIC_API_KEY=<your key if needed>
```

**Frontend (.env):**
```bash
cd /app/frontend
nano .env
```

Verify:
```bash
REACT_APP_BACKEND_URL=http://localhost:8001
```

#### Reinstall Dependencies

```bash
# Backend
cd /app/backend
pip3 install -r requirements.txt

# Frontend
cd /app/frontend
yarn install  # or npm install
```

#### Seed Database

```bash
cd /app/backend
python3 seed.py
python3 seed_menu.py
python3 seed_pages.py
python3 seed_collections_lots.py  # if needed
```

#### Restart Services

```bash
sudo supervisorctl restart all
```

---

## 3️⃣ Rollback to Previous Version

### When to Use

- Update caused bugs or errors
- Services won't start after update
- Need to restore previous working state
- Database corruption

### How to Rollback

```bash
sudo bash rollback_deployment.sh
```

### Interactive Process

1. **View available backups:**
   ```
   Available Backups:

   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     [1] 2025-01-27 10:30  |  245M  |  With DB
     [2] 2025-01-27 09:15  |  243M  |  With DB
     [3] 2025-01-26 15:20  |  240M  |  No DB
     [4] 2025-01-25 14:10  |  238M  |  With DB
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   Select backup number to restore (1-4) or 0 to cancel: 1
   ```

2. **Confirm rollback:**
   ```
   Selected Backup:
     📁 backup_20250127_103045
     📂 /app_backups/backup_20250127_103045

   ⚠ This will replace your current deployment!

   ❓ Are you sure you want to rollback?
      (Y/N, Default: N)
      Your answer: Y
   ```

3. **Safety backup created automatically**

4. **Services stopped**

5. **Code restored**

6. **Database restore option:**
   ```
   ❓ Restore database as well?
      (Y/N, Default: Y)
      Your answer: Y
   ```

7. **Services restarted**

8. **Health check performed**

### Result

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Rollback Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ⏮️  Restored to: backup_20250127_103045
  💾 Safety backup: before_rollback_20250127_104512

Service Status:
auction-backend      RUNNING   pid 5678, uptime 0:00:15
auction-frontend     RUNNING   pid 5679, uptime 0:00:15
```

### If Rollback Fails

You can restore from the safety backup:

```bash
rm -rf /app
cp -r /app_backups/before_rollback_20250127_104512 /app
sudo supervisorctl restart all
```

---

## 4️⃣ Backup Management

### Automatic Backups

Backups are automatically created:
- ✅ When switching repositories (mandatory)
- ✅ When you choose "yes" during update
- ✅ Before every rollback (safety backup)

**Location:** `/app_backups/`

### Manual Backup

Create a backup anytime:

```bash
sudo bash update_deployment.sh --backup
```

Or during interactive update, choose "Y" when asked.

### Backup Structure

```
/app_backups/
├── backup_20250127_103045/      # Main backup
│   ├── backend/                 # All backend code
│   ├── frontend/                # All frontend code
│   └── db_backup/              # MongoDB dump
│       └── your_database/
│           ├── collections.bson
│           ├── users.bson
│           └── ...
├── backup_20250127_091530/
├── backup_20250126_152045/
└── before_rollback_20250127_104512/  # Safety backup
```

### View Backups

```bash
ls -lh /app_backups/
```

### Backup Retention

- **Automatic cleanup:** Keeps only last 5 backups
- **Safety backups:** Not auto-deleted
- **Manual cleanup:**
  ```bash
  # Remove specific backup
  sudo rm -rf /app_backups/backup_20250126_152045
  
  # Remove all old backups (keeps last 3)
  cd /app_backups
  ls -t | tail -n +4 | xargs sudo rm -rf
  ```

### Restore Backup Manually

```bash
# Stop services
sudo supervisorctl stop all

# Restore code
sudo rm -rf /app
sudo cp -r /app_backups/backup_20250127_103045 /app

# Restore database
cd /app_backups/backup_20250127_103045
source /app/backend/.env
mongorestore --db $DB_NAME --drop db_backup/$DB_NAME

# Restart services
sudo supervisorctl restart all
```

---

## 5️⃣ Git Workflows

### Typical Development Workflow

1. **Make changes locally:**
   ```bash
   # On your development machine
   cd ~/my-auction-app
   # Make code changes
   git add .
   git commit -m "Updated collections page"
   git push origin main
   ```

2. **Update server:**
   ```bash
   # On server
   ssh ubuntu@your-server
   cd /app
   sudo bash quick_update.sh
   ```

3. **Verify changes:**
   ```bash
   # Check logs
   tail -f /var/log/supervisor/auction-backend.err.log
   
   # Test in browser
   curl http://localhost:8001/api/collections
   ```

### Working with Branches

#### Deploy Different Branch

```bash
cd /app
git fetch origin
git checkout production
git pull origin production
sudo supervisorctl restart all
```

#### Switch Branch

```bash
cd /app

# See current branch
git branch --show-current

# See all branches
git branch -a

# Switch branch
git checkout develop
git pull origin develop

# Update dependencies if needed
cd backend && pip3 install -r requirements.txt
cd ../frontend && yarn install

# Restart
sudo supervisorctl restart all
```

### Multiple Environments

Deploy same app to different directories for staging/production:

```bash
# Production in /app
cd /app
git checkout main

# Staging in /app-staging
sudo cp -r /app /app-staging
cd /app-staging
git checkout develop
sudo supervisorctl restart all
```

---

## 6️⃣ Troubleshooting

### Update Failed - Git Conflicts

**Problem:** Git pull fails with merge conflicts

**Solution:**

```bash
cd /app

# Option 1: Stash local changes
git stash
git pull
git stash pop  # Reapply changes if needed

# Option 2: Reset to remote
git fetch origin
git reset --hard origin/main

# Option 3: Fresh clone
sudo bash update_deployment.sh --new-repo
# Enter same repository URL
```

### Services Won't Start After Update

**Problem:** Backend or frontend not starting

**Solution:**

```bash
# Check logs
tail -f /var/log/supervisor/auction-backend.err.log

# Common fixes:

# 1. Missing dependencies
cd /app/backend
pip3 install -r requirements.txt
cd /app/frontend
yarn install

# 2. Environment variables
cat /app/backend/.env
cat /app/frontend/.env
# Verify all required variables present

# 3. Port conflicts
sudo netstat -tulpn | grep -E ':(3000|8001)'
# Kill conflicting processes if found

# 4. Restart services
sudo supervisorctl restart all

# 5. If still failing, rollback
sudo bash rollback_deployment.sh
```

### Backup Failed

**Problem:** "No space left on device" when creating backup

**Solution:**

```bash
# Check disk space
df -h

# Clean old backups
cd /app_backups
sudo ls -t | tail -n +2 | xargs rm -rf

# Clean system
sudo apt-get clean
sudo apt-get autoremove

# Clear old logs
sudo find /var/log -type f -name "*.log" -mtime +30 -delete
```

### Can't Pull from Git

**Problem:** Permission denied or authentication failed

**Solution:**

```bash
cd /app

# Check remote URL
git remote -v

# If using HTTPS with private repo
git remote set-url origin https://YOUR_USERNAME:YOUR_TOKEN@github.com/user/repo.git

# If using SSH
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
cat ~/.ssh/id_rsa.pub
# Add to GitHub: Settings → SSH Keys

# Test connection
ssh -T git@github.com
```

### Database Not Restored

**Problem:** Database empty after rollback

**Solution:**

```bash
# Check if backup has database
ls -la /app_backups/backup_20250127_103045/db_backup/

# Manual restore
cd /app/backend
source .env
mongorestore --db $DB_NAME --drop /app_backups/backup_20250127_103045/db_backup/$DB_NAME

# If no backup, re-seed
python3 seed.py
python3 seed_menu.py
python3 seed_pages.py
```

---

## 📊 Best Practices

### ✅ DO

1. **Always create backups before major updates**
   ```bash
   sudo bash update_deployment.sh --backup
   ```

2. **Test updates on staging first**
   - Clone to separate directory
   - Test thoroughly
   - Then update production

3. **Use quick update for small changes**
   ```bash
   sudo bash quick_update.sh
   ```

4. **Monitor logs after updates**
   ```bash
   tail -f /var/log/supervisor/*.err.log
   ```

5. **Keep backups for important releases**
   ```bash
   cp -r /app_backups/backup_20250127_103045 /app_backups/v1.0_release
   ```

### ❌ DON'T

1. **Don't update without backup on production**
2. **Don't skip dependency updates if requirements changed**
3. **Don't ignore error logs**
4. **Don't delete all backups**
5. **Don't make manual changes without git commit**

---

## 🎯 Quick Decision Guide

```
┌─────────────────────────────────────────────┐
│ What do you need to do?                     │
└─────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
    Small code              Major change
    changes?                or new repo?
        │                       │
        ▼                       ▼
┌───────────────┐       ┌───────────────────┐
│ quick_update  │       │ update_deployment │
│    .sh        │       │      .sh          │
└───────────────┘       └───────────────────┘
                                │
                    ┌───────────┴────────┐
                    │                    │
               Update from           Switch to
               current repo?         new repo?
                    │                    │
                    ▼                    ▼
            ┌──────────────┐    ┌──────────────┐
            │ Choose opt 1 │    │ Choose opt 2 │
            │ Follow       │    │ or use       │
            │ prompts      │    │ --new-repo   │
            └──────────────┘    └──────────────┘

┌─────────────────────────────────────────────┐
│ Something went wrong?                       │
└─────────────────────────────────────────────┘
                    │
                    ▼
            ┌──────────────────┐
            │ rollback_        │
            │ deployment.sh    │
            └──────────────────┘
```

---

## 📞 Support

### Quick Commands Reference

```bash
# Update
sudo bash quick_update.sh
sudo bash update_deployment.sh
sudo bash update_deployment.sh --new-repo

# Rollback
sudo bash rollback_deployment.sh

# Status
sudo supervisorctl status
git log --oneline -10
git branch --show-current

# Logs
tail -f /var/log/supervisor/auction-backend.err.log
tail -f /var/log/supervisor/auction-frontend.err.log

# Backups
ls -lh /app_backups/
du -sh /app_backups/*
```

### Common Issues Solutions

| Issue | Command |
|-------|---------|
| Git conflicts | `cd /app && git stash && git pull` |
| Service down | `sudo supervisorctl restart all` |
| Wrong branch | `cd /app && git checkout main && git pull` |
| Need rollback | `sudo bash rollback_deployment.sh` |
| Check versions | `cd /app && git log --oneline -5` |

---

**Happy Deploying! 🚀**
