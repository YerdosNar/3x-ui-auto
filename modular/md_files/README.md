# 3X-UI Automated Installer v2.0

Automated installation script for 3X-UI panel with Docker and Caddy reverse proxy support.

## 📁 Project Structure

```
.
├── install.sh              # Main installation script
├── functions/              # Modular function files
│   ├── logger.sh          # Logging system (console + file)
│   ├── config.sh          # Configuration & state management
│   ├── validators.sh      # Input validation functions
│   ├── utils.sh           # Utility helper functions
│   ├── requirements.sh    # System requirements checker
│   ├── docker.sh          # Docker installation module
│   ├── compose.sh         # Docker Compose configuration
│   ├── panel.sh           # 3X-UI panel auto-configuration
│   └── caddy.sh           # Caddy installation & setup
└── README.md              # This file
```

## 🚀 Quick Start

### Installation

- #### Automated
```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/custom_logs.sh)
```
Creates a temporal directory, where it will store necessary scripts. And upon completion, it deletes the directory with scripts by user's choice.

- #### Manual
```bash
git clone https://github.com/YerdosNar/3x-ui-auto.git
cd 3x-ui-auto/modular
chmod +x install.sh
./install.sh
```

### What It Does

1. **System Check**: Validates OS, disk space, and required commands
2. **Docker Installation**: Installs Docker and Docker Compose if needed
3. **3X-UI Setup**: Creates and starts 3X-UI container
4. **Caddy Setup** (optional): Configures HTTPS reverse proxy with automatic SSL
5. **Panel Configuration**: Automatically configures panel settings

## 📝 Features

### Clean Logging System
- All operations logged to both console and file
- Log file: `/tmp/.3xui_install_logs_<PID>.txt`
- Only custom logs shown on screen (no command output clutter)
- Detailed logs saved for troubleshooting

### Modular Architecture
- Each function module handles specific tasks
- Easy to maintain and extend
- Clear separation of concerns

### Smart Installation Flow
- Detects existing installations
- Handles Docker group membership (automatic logout/reboot)
- State management for resuming interrupted installations
- Validates all user inputs

### Security Features
- Strong password generation
- HTTPS with automatic SSL certificates (via Caddy)
- HTTP Basic Auth for admin panel
- Security headers configured

## 📋 Requirements

- Ubuntu/Debian-based system
- Minimum 2GB free disk space
- Sudo privileges
- Internet connection

## 🔧 Configuration

### Installation Directory
Default: `~/3x-uiPANEL`

Contains:
- `compose.yml` - Docker Compose configuration
- `Caddyfile` - Caddy reverse proxy configuration (if installed)
- `db/` - Panel database
- `cert/` - SSL certificates

### Default Ports
- Panel (before Caddy): `2053`
- Backend (with Caddy): `2087` (configurable)
- API Port: `8443` (configurable)

## 📖 Usage Examples

### With Domain (HTTPS)
```bash
./install.sh
# Choose 'y' when asked about domain
# Enter your domain name
# Choose 'Y' for Caddy installation
# Follow prompts for credentials and ports
```

### Without Domain (HTTP only)
```bash
./install.sh
# Choose 'n' when asked about domain
# Panel accessible via: http://<SERVER_IP>:2053
# Default credentials: admin/admin
```

## 🔍 Logging Details

### Log Location
Logs are saved to: `/tmp/.3xui_install_logs_<PID>.txt`

### Log Levels
- `[INFO]` - Informational messages
- `[SUCCESS]` - Successful operations
- `[WARNING]` - Non-critical warnings
- `[ERROR]` - Critical errors
- `[EXEC]` - Command execution details
- `[STATE]` - State management events
- `[SYSTEM]` - System information
- `[DOCKER]` - Docker operations
- `[CADDY]` - Caddy operations
- `[PANEL]` - Panel configuration events

### View Logs
```bash
# During installation
tail -f /tmp/.3xui_install_logs_<PID>.txt

# After installation (find latest)
ls -lt /tmp/.3xui_install_logs_*.txt | head -1
```

## 🛠️ Useful Commands

### Docker Commands
```bash
cd ~/3x-uiPANEL

# View logs
docker compose logs -f

# Restart container
docker compose restart

# Stop container
docker compose down

# Start container
docker compose up -d

# Check status
docker ps
```

### Caddy Commands
```bash
# Check status
sudo systemctl status caddy

# Restart Caddy
sudo systemctl restart caddy

# View logs
sudo journalctl -u caddy -f

# Validate config
sudo caddy validate --config /etc/caddy/Caddyfile
```

## 🔄 State Management

The installer uses state files to handle interruptions (e.g., Docker group membership requiring logout/reboot).

State file: `/tmp/.3xui_install_state`

If installation is interrupted:
1. Log out/reboot as instructed
2. Run the script again
3. It will resume from where it left off

## 🐛 Troubleshooting

### Docker Group Issues
If you see "permission denied" errors with Docker:
```bash
# Verify group membership
groups $USER

# If 'docker' not in list, logout and login again
# Or reboot the system
```

### Caddy SSL Issues
Check DNS is pointing to your server:
```bash
dig +short yourdomain.com
# Should return your server's IP
```

### Panel Not Accessible
Check if container is running:
```bash
docker ps | grep 3xui
docker logs 3xui_app
```

Check Caddy status:
```bash
sudo systemctl status caddy
sudo journalctl -u caddy -n 50
```

### View Full Logs
```bash
# Find your log file
ls -lt /tmp/.3xui_install_logs_*.txt

# View it
cat /tmp/.3xui_install_logs_<PID>.txt
```

## 📄 License

This project is provided as-is for educational and personal use.

## 🤝 Contributing

Contributions are welcome! Please ensure:
- Code follows existing structure
- All functions include logging
- Test on Ubuntu/Debian systems
- Update README for new features

## ⚠️ Security Notes

1. **Change Default Credentials**: Always change default admin credentials after installation
2. **Firewall**: Configure firewall to restrict access to management ports
3. **Updates**: Keep Docker and Caddy updated regularly
4. **Backups**: Backup `~/3x-uiPANEL/db/` directory regularly

## 📞 Support

For issues and questions:
- Check logs: `/tmp/.3xui_install_logs_*.txt`
- Review README troubleshooting section
- Check existing GitHub issues
- Create new issue with logs attached

---

**Note**: This installer automates the setup process but requires basic understanding of Linux system administration for maintenance and troubleshooting.
