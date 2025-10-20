# Setup Guide - Creating the Project Structure

This guide shows how to create the complete modularized project structure.

## 🚀 Quick Setup Commands

### Option 1: Manual Setup

```bash
# Create project directory
mkdir -p 3x-ui-auto/functions
cd 3x-ui-auto

# Create main install script
cat > install.sh << 'EOF'
[Copy content from install.sh artifact]
EOF

# Make it executable
chmod +x install.sh

# Create function modules
cd functions

# Create logger.sh
cat > logger.sh << 'EOF'
[Copy content from functions/logger.sh artifact]
EOF

# Create config.sh
cat > config.sh << 'EOF'
[Copy content from functions/config.sh artifact]
EOF

# Create validators.sh
cat > validators.sh << 'EOF'
[Copy content from functions/validators.sh artifact]
EOF

# Create utils.sh
cat > utils.sh << 'EOF'
[Copy content from functions/utils.sh artifact]
EOF

# Create requirements.sh
cat > requirements.sh << 'EOF'
[Copy content from functions/requirements.sh artifact]
EOF

# Create docker.sh
cat > docker.sh << 'EOF'
[Copy content from functions/docker.sh artifact]
EOF

# Create compose.sh
cat > compose.sh << 'EOF'
[Copy content from functions/compose.sh artifact]
EOF

# Create panel.sh
cat > panel.sh << 'EOF'
[Copy content from functions/panel.sh artifact]
EOF

# Create caddy.sh
cat > caddy.sh << 'EOF'
[Copy content from functions/caddy.sh artifact]
EOF

# Make all function modules executable
chmod +x *.sh

# Return to project root
cd ..

# Create README
cat > README.md << 'EOF'
[Copy content from README.md artifact]
EOF

# Create documentation
cat > PROJECT_STRUCTURE.md << 'EOF'
[Copy content from PROJECT_STRUCTURE.md artifact]
EOF
```

### Option 2: Clone from Repository

```bash
# Clone the repository
git clone https://github.com/YerdosNar/3x-ui-auto.git
cd 3x-ui-auto

# Make install script executable
chmod +x install.sh

# Make all function modules executable
chmod +x functions/*.sh

# Run the installer
./install.sh
```

## 📁 Verify Directory Structure

After setup, verify the structure:

```bash
tree -L 2 3x-ui-auto/
```

Expected output:
```
3x-ui-auto/
├── install.sh
├── functions
│   ├── caddy.sh
│   ├── compose.sh
│   ├── config.sh
│   ├── docker.sh
│   ├── logger.sh
│   ├── panel.sh
│   ├── requirements.sh
│   ├── utils.sh
│   └── validators.sh
├── README.md
├── PROJECT_STRUCTURE.md
└── SETUP.md

1 directory, 13 files
```

## 🔧 Configuration Check

Before running the installer, verify:

### 1. File Permissions
```bash
# Check if install.sh is executable
ls -l install.sh
# Should show: -rwxr-xr-x

# Check function modules
ls -l functions/*.sh
# All should be readable
```

### 2. Bash Syntax
```bash
# Verify no syntax errors
bash -n install.sh

# Check each module
for file in functions/*.sh; do
    echo "Checking $file..."
    bash -n "$file"
done
```

### 3. Dependencies
```bash
# Check required commands
command -v curl && echo "✓ curl found"
command -v gpg && echo "✓ gpg found"
command -v apt-get && echo "✓ apt-get found"
command -v systemctl && echo "✓ systemctl found"
```

## 🧪 Test Installation

### Dry Run (Check Only)
```bash
# View what would happen without making changes
bash -x install.sh 2>&1 | head -n 50
```

### Test on Clean System
```bash
# Recommended: Test on a VPS or VM first
# Fresh Ubuntu 22.04 or Debian 11+

# As regular user (not root):
./install.sh
```

## 📝 Customization Before Running

### Change Installation Directory
Edit `functions/config.sh`:
```bash
readonly INSTALL_DIR="$HOME/3x-uiPANEL"  # Change this line
```

### Change Default Ports
Edit `functions/caddy.sh`:
```bash
# Find these lines and change defaults:
read -p "Enter API port [default: 8443]: " PORT
PORT=${PORT:-8443}  # Change 8443 to your preferred port
```

### Modify Logging
Edit `functions/logger.sh`:
```bash
# Change log file location
readonly LOG_FILE="/tmp/.3xui_install_logs_$$.txt"
# Change to: readonly LOG_FILE="/var/log/3xui_install_$$.log"
```

## 🔐 Security Hardening (Optional)

### Restrict Log File Access
```bash
# After installation, move logs to secure location
sudo mkdir -p /var/log/3xui
sudo mv /tmp/.3xui_install_logs_*.txt /var/log/3xui/
sudo chmod 600 /var/log/3xui/*
```

### Change Default State File Location
Edit `functions/config.sh`:
```bash
# Make state file more secure
readonly STATE_FILE="$HOME/.3xui_install_state"
# Instead of: /tmp/.3xui_install_state
```

## 🚦 Pre-Flight Checklist

Before running the installer:

- [ ] **System**: Ubuntu 22.04+ or Debian 11+
- [ ] **User**: Regular user (not root) with sudo privileges
- [ ] **Network**: Internet connection active
- [ ] **Space**: At least 2GB free disk space
- [ ] **Backup**: Important data backed up (if any)
- [ ] **Permissions**: `install.sh` is executable
- [ ] **Domain**: DNS configured (if using domain)
- [ ] **Ports**: Ensure required ports are not in use
  - 2053 (initial panel)
  - 8443 (API - or your chosen port)
  - 2087 (backend - or your chosen port)
  - 80/443 (Caddy, if using domain)

## 🎯 Installation Paths

### With Domain (HTTPS + Auto-config)
```bash
./install.sh
# Answer: y (have domain)
# Enter: your-domain.com
# Answer: Y (install Caddy)
# Choose: Y (generate password) or enter manually
# Enter: route nickname (or press Enter for default)
# Enter: API port (or press Enter for 8443)
# Enter: Backend port (or press Enter for 2087)
# Wait for auto-configuration
# Access: https://your-domain.com/admin
```

### Without Domain (HTTP only)
```bash
./install.sh
# Answer: n (no domain)
# Installation completes
# Access: http://YOUR_SERVER_IP:2053
# Default: admin/admin (change immediately!)
```

### With Domain but No Caddy
```bash
./install.sh
# Answer: y (have domain)
# Enter: your-domain.com
# Answer: n (skip Caddy)
# Access: http://your-domain.com:2053
# Default: admin/admin
```

## 📊 Post-Installation Verification

### 1. Check Docker Container
```bash
cd ~/3x-uiPANEL
docker compose ps
# Should show 3xui_app running
```

### 2. Check Caddy (if installed)
```bash
sudo systemctl status caddy
# Should show active (running)
```

### 3. Test Panel Access
```bash
# With domain:
curl -I https://your-domain.com/admin

# Without domain:
curl -I http://YOUR_IP:2053
```

### 4. Review Logs
```bash
# Find and view installation log
ls -lt /tmp/.3xui_install_logs_*.txt | head -1
cat $(ls -t /tmp/.3xui_install_logs_*.txt | head -1)
```

## 🔄 Updating the Installation

### Update Docker Images
```bash
cd ~/3x-uiPANEL
docker compose pull
docker compose up -d
```

### Update Caddy
```bash
sudo apt update
sudo apt upgrade caddy
sudo systemctl restart caddy
```

## 🗑️ Complete Uninstallation

If you need to remove everything:

```bash
# Stop and remove containers
cd ~/3x-uiPANEL
docker compose down -v

# Remove installation directory
rm -rf ~/3x-uiPANEL

# Remove Caddy (optional)
sudo systemctl stop caddy
sudo systemctl disable caddy
sudo apt remove caddy
sudo rm /etc/caddy/Caddyfile
sudo rm /etc/apt/sources.list.d/caddy-stable.list

# Clean up logs and state
rm -f /tmp/.3xui_install_*
```

## 📞 Getting Help

### Check Logs First
```bash
# Installation logs
cat /tmp/.3xui_install_logs_*.txt

# Docker logs
docker logs 3xui_app

# Caddy logs
sudo journalctl -u caddy -n 100
```

### Common Commands
```bash
# Restart panel
cd ~/3x-uiPANEL && docker compose restart

# Restart Caddy
sudo systemctl restart caddy

# View panel database
sqlite3 ~/3x-uiPANEL/db/x-ui.db ".tables"
```

### Report Issues
When reporting issues, include:
1. OS version: `cat /etc/os-release`
2. Installation log: Content of `/tmp/.3xui_install_logs_*.txt`
3. Error messages: Complete error output
4. Steps to reproduce

---

**Ready to install?** Run: `./install.sh`

**Need help?** Check: `README.md` and `PROJECT_STRUCTURE.md`
