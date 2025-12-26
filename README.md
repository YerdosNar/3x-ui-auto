# 🚀 3X-UI Auto Installer

**Automated one-liner installer** for [3X-UI panel](https://github.com/mhsanaei/3x-ui) with Docker, Caddy reverse proxy, smart firewall, and network optimization.

## ✨ Features

- 🐳 **Docker & Docker Compose** - Automatic installation and configuration
- 🔒 **Caddy Reverse Proxy** - HTTPS with automatic SSL certificates
- 🛡️ **Smart Firewall (UFW)** - Auto-detects and opens required ports
- ⚡ **Network Optimization** - BBR congestion control for 20-30x faster speeds
- 🎯 **Smart Port Detection** - Never locks you out of SSH
- 🔧 **Automatic Configuration** - 3X-UI panel ready to use
- 📊 **Multiple Installations** - Support for multiple 3X-UI instances

---

## 🚀 Quick Start

### One-Liner Installation

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/install.sh)
```

### Modular Installation (Recommended)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/modular/install.sh)
```

### With Logging (for troubleshooting)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/custom_logs.sh)
```

> ⚠️ Requires `sudo` privileges and Ubuntu/Debian system

---

## 📋 What Gets Installed

### Core Components
1. **Docker & Docker Compose** - Container runtime
2. **3X-UI Panel** - Web-based VPN/proxy management
3. **Caddy (Optional)** - HTTPS reverse proxy with auto SSL

### Optional Enhancements
4. **UFW Firewall** - Smart port management and security
5. **Network Optimization** - BBR congestion control and TCP tuning

---

## 🎯 Installation Process

The installer will guide you through:

1. **Domain Setup** - Enter your domain or use IP address
2. **Caddy Configuration** (if domain provided)
   - Admin credentials
   - Route path (e.g., `/admin`)
   - API and backend ports
3. **Network Optimization** - Apply BBR and TCP tuning (recommended)
4. **Firewall Setup** - Configure UFW with smart port detection (recommended)

---

## 🌐 Access Your Panel

After installation:

| Setup Type | URL | Default Login |
|------------|-----|---------------|
| **With Domain** | `https://yourdomain.com/admin` | Your custom credentials |
| **Without Domain** | `http://YOUR_IP:2053` | `admin` / `admin` |

> ⚠️ **Change default credentials immediately** if not using Caddy!

---

## 🛡️ Firewall & Network Features

### Smart Firewall (UFW)
- ✅ Auto-detects SSH port (never locks you out!)
- ✅ Opens required ports: HTTP (80), HTTPS (443), 3X-UI (2053)
- ✅ Configures port ranges for VPN inbounds (8380-8400, 9380-9400)
- ✅ Enables IP forwarding for proxy functionality

### Network Optimization
- ⚡ **BBR Congestion Control** - 20-30x faster speeds
- 📦 **Fair Queue Scheduling** - Reduced latency
- 💾 **64MB TCP Buffers** - Better throughput
- 🚀 **TCP Fast Open** - Faster connections

**Performance:** Shadowsocks/VLESS speeds improved from 5 Mbps to **150-170 Mbps**!

📖 **Details:** See [Firewall & Network Guide](modular/md_files/FIREWALL_NETWORK_GUIDE.md)

---

## 🔧 Useful Commands

### Docker Management
```bash
cd ~/3x-uiPANEL*
docker compose up -d        # Start
docker compose down         # Stop
docker compose restart      # Restart
docker compose logs -f      # View logs
```

### Caddy Management
```bash
sudo systemctl status caddy    # Check status
sudo systemctl restart caddy   # Restart
sudo caddy validate            # Test config
```

### Firewall Management
```bash
sudo ufw status               # View rules
sudo ufw allow 9000/tcp       # Open port
sudo ufw delete allow 9000    # Close port
```

### Network Check
```bash
sysctl net.ipv4.tcp_congestion_control  # Check BBR
sysctl net.core.default_qdisc           # Check queue
```

---

## 🗑️ Uninstallation

### Remove Single Installation
```bash
# Interactive - choose which installation to remove
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh)

# Or specify directory number
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -d 1
```

### List All Installations
```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -l
```

📖 **Details:** See [Uninstall Guide](modular/md_files/UNINSTALL_USAGE.md)

---

## 📚 Documentation

- 📘 [Caddyfile Management](modular/md_files/CADDYFILE_MANAGEMENT.md) - Handle multiple domains
- 🛡️ [Firewall & Network Guide](modular/md_files/FIREWALL_NETWORK_GUIDE.md) - UFW + BBR optimization
- 🗑️ [Uninstall Guide](modular/md_files/UNINSTALL_USAGE.md) - Remove installations safely
- 📝 [Project Structure](modular/md_files/PROJECT_STRUCTURE.md) - Code organization
- ⚙️ [Setup Guide](modular/md_files/SETUP.md) - Detailed installation steps
- 🚀 [VPS Optimization Notes](modular/md_files/VPS_Speed_Security_Optimization_Notes.md) - Performance tuning

---

## 🗂️ Directory Structure

```
3x-ui-auto/
├── one_liner.sh           # Standalone installer
├── custom_logs.sh         # Installer with logging
├── uninstall.sh          # Uninstaller with smart detection
├── modular/              # Modular installer
│   ├── install.sh        # Main entry point
│   ├── functions/        # Function modules
│   │   ├── logger.sh
│   │   ├── docker.sh
│   │   ├── caddy.sh
│   │   ├── firewall.sh           # Smart UFW management
│   │   ├── network_optimization.sh  # BBR + TCP tuning
│   │   └── ...
│   └── md_files/         # Documentation
└── README.md             # This file
```

---

## ⚙️ Requirements

- **OS:** Ubuntu 20.04+ or Debian 10+
- **Access:** Root or sudo privileges
- **Network:** Internet connection
- **Kernel:** 4.9+ (for BBR support)

---

## 🔍 Troubleshooting

### Docker Permission Issues
```bash
newgrp docker
# Or logout and login again
```

### Port Conflicts
Check if ports are in use:
```bash
sudo lsof -i :2053
sudo lsof -i :443
```

### Firewall Locked Out
Access via VPS console and run:
```bash
sudo ufw disable
# Or
sudo ufw allow 22/tcp
```

### BBR Not Enabled
Check kernel version:
```bash
uname -r  # Should be 4.9+
```

For more troubleshooting, see the [documentation](#-documentation) section.

---

## 💡 Tips

- ✅ **Use a domain** for HTTPS and better security
- ✅ **Enable network optimization** for 20-30x faster speeds
- ✅ **Configure firewall** for security
- ✅ **Change default credentials** if not using Caddy
- ✅ **Regular backups** of `~/3x-uiPANEL*/db/` directory

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

## 🧑‍💻 Author

**Yerdos Narzhigitov**
📦 [GitHub: @YerdosNar](https://github.com/YerdosNar)

---

## 🪪 License

This project is released under the [GPL-v3 License](LICENSE)
(Same as the [3X-UI](https://github.com/MHSanaei/3x-ui) project)

---

## 📖 Related Projects

- [3X-UI Panel](https://github.com/mhsanaei/3x-ui) - Original panel
- [Caddy](https://caddyserver.com/) - Reverse proxy server
- [Docker](https://www.docker.com/) - Container platform

---

> 💬 *Feedback and pull requests are welcome!*
