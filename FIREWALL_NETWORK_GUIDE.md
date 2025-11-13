# 🔥 Firewall & Network Optimization Guide

## Overview

The 3X-UI installer now includes **Smart Firewall Management** and **Comprehensive Network Optimization** modules that automatically configure your VPS for optimal VPN/proxy performance and security.

---

## 🛡️ Firewall Module (UFW)

### Features

#### 🎯 Smart Port Detection
- **Automatically detects** required ports based on your installation
- **SSH protection** - Never blocks SSH (auto-detects custom SSH ports)
- **Web server ports** - Opens 80/443 if Caddy is installed
- **3X-UI ports** - Opens panel port (2053) and configured API/backend ports
- **Port ranges** - Supports opening ranges like 8380-8400 for inbounds

#### 🔒 Security Features
- Default deny incoming traffic
- Allow all outgoing traffic
- IP forwarding enabled for VPN/proxy functionality
- Safe UFW enablement (won't lock you out)

#### 📊 User-Friendly
- Interactive port selection
- Shows all ports before applying
- Confirmation prompts for safety
- Real-time status display

---

## ⚡ Network Optimization Module

### What Gets Optimized

#### 🚀 Google BBR Congestion Control
**What it does:**
- Smarter bandwidth usage algorithm
- Better performance on high-latency/long-distance connections
- Reduces bufferbloat

**Expected improvement:**
- 20-30x speed increase for Shadowsocks/VLESS
- Lower latency and reduced jitter
- Better throughput under network congestion

#### 📦 Fair Queue (FQ) Scheduling
**What it does:**
- Fair packet scheduling across connections
- Prevents single connection from hogging bandwidth

**Expected improvement:**
- Reduced latency spikes
- Fair distribution of network resources
- Smoother performance under load

#### 💾 TCP Buffer Tuning
**What it does:**
- Increases send/receive buffer sizes
- Optimized for high-throughput transfers

**Settings applied:**
```bash
net.core.rmem_max=67108864        # 64 MB receive buffer
net.core.wmem_max=67108864        # 64 MB send buffer
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
```

**Expected improvement:**
- Prevents packet loss under high traffic
- Better handling of large transfers
- Improved throughput

#### ⚡ TCP Fast Open & Reuse
**What it does:**
- TCP Fast Open (TFO) - Reduces connection establishment time
- TCP TIME_WAIT reuse - Faster socket recycling

**Expected improvement:**
- Faster connection startup
- Reduced connection overhead
- Better performance for short-lived connections

#### 🌐 IP Forwarding
**What it does:**
- Enables packet forwarding for VPN/proxy traffic
- Essential for proper proxy functionality

**Settings applied:**
```bash
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
```

---

## 📋 Installation Flow

### During Installation

The installer will prompt you with two questions:

```
Apply network optimizations (BBR, TCP tuning)? [Y/n]:
```
**Recommended:** Yes
- Applies all network optimizations
- Dramatically improves VPN/proxy performance
- Safe for all systems

```
Configure UFW firewall? [Y/n]:
```
**Recommended:** Yes
- Sets up secure firewall rules
- Auto-detects required ports
- Protects your server

---

## 🎮 Usage Examples

### Automatic Setup (Recommended)

Just answer "Y" to both prompts during installation:

```bash
Apply network optimizations (BBR, TCP tuning)? [Y/n]: Y
Configure UFW firewall? [Y/n]: Y
```

The installer will:
1. ✅ Detect your SSH port
2. ✅ Detect required ports (80, 443, API, backend)
3. ✅ Show you what will be opened
4. ✅ Apply network optimizations
5. ✅ Configure firewall rules
6. ✅ Verify everything works

### What You'll See

**Network Optimization:**
```
═══════════════════════════════════════════════════════════
           Network Optimization Setup
═══════════════════════════════════════════════════════════

Current Configuration:
  Queue Discipline: pfifo_fast
  TCP Congestion Control: cubic
  TCP Fast Open: not set
  IPv4 Forwarding: 0

Apply network optimizations? [Y/n]: Y

[INFO] Applying network optimizations to /etc/sysctl.conf...
[✓]    Backup created: /etc/sysctl.conf.backup.1731456789
[✓]    Network optimizations added
[INFO] Loading sysctl settings...
[✓]    Sysctl settings loaded successfully!

Applied Configuration:
  ✓ Queue Discipline: fq
  ✓ TCP Congestion Control: bbr
  ✓ TCP Fast Open: 3
  ✓ IPv4 Forwarding: Enabled
  ✓ IPv6 Forwarding: Enabled
```

**Firewall Setup:**
```
═══════════════════════════════════════════════════════════
           UFW Firewall Setup
═══════════════════════════════════════════════════════════

[INFO] Detecting required ports...
[✓]    Port detection completed

Ports that will be opened:
  • 22/tcp - SSH
  • 80/tcp - HTTP
  • 443/tcp - HTTPS
  • 2053/tcp - 3X-UI
  • 2087/tcp - BACKEND
  • 8443/tcp - API
  • 8443/udp - API_UDP

Proceed with these ports? [Y/n]: Y

[INFO] Opening port: 22/tcp (SSH)
[✓]      ✓ 22/tcp opened
[INFO] Opening port: 80/tcp (HTTP)
[✓]      ✓ 80/tcp opened
...

Open port range 8380-8400 (TCP/UDP)? [Y/n]: Y
[INFO] Opening ports 8380-8400...
[✓]      ✓ Ports 8380-8400 (TCP/UDP) opened

[✓]    UFW enabled successfully!

Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
2053/tcp                   ALLOW       Anywhere
2087/tcp                   ALLOW       Anywhere
8443                       ALLOW       Anywhere
8380:8400/tcp              ALLOW       Anywhere
8380:8400/udp              ALLOW       Anywhere
```

---

## 🔧 Manual Management

### Check Current Settings

**Network optimization status:**
```bash
# Check BBR
sysctl net.ipv4.tcp_congestion_control

# Check queue discipline
sysctl net.core.default_qdisc

# Check IP forwarding
sysctl net.ipv4.ip_forward
```

**Firewall status:**
```bash
sudo ufw status numbered
```

### Open Additional Ports

```bash
# Open single port
sudo ufw allow 9000/tcp
sudo ufw allow 9000/udp

# Open port range
sudo ufw allow 9000:9100/tcp
sudo ufw allow 9000:9100/udp

# Open for specific IP
sudo ufw allow from 1.2.3.4 to any port 9000
```

### Close Ports

```bash
# Close single port
sudo ufw delete allow 9000/tcp

# Close port range
sudo ufw delete allow 9000:9100/tcp
```

### View All Rules

```bash
sudo ufw status numbered
```

### Delete Rule by Number

```bash
sudo ufw status numbered
# Note the rule number
sudo ufw delete [number]
```

### Disable UFW

```bash
sudo ufw disable
```

### Re-enable UFW

```bash
sudo ufw enable
```

---

## 📊 Performance Benchmarks

Based on real-world testing (from VPS_Speed_Security_Optimization_Notes.md):

| Metric | Before Optimization | After Optimization |
|:-------|:-------------------:|:------------------:|
| VPS Baseline | 190↓ / 150↑ Mbps | — |
| Shadowsocks (xchacha20) | 5↓ / 5↑ Mbps | **170↓ / 40↑ Mbps** |
| VLESS | 5↓ / 5↑ Mbps | **150↓ / 10↑ Mbps** |

**Improvement:** Up to **34x faster** download speeds! 🚀

---

## ⚙️ Advanced Configuration

### Customize Network Settings

Edit `/etc/sysctl.conf` and modify values:

```bash
sudo nano /etc/sysctl.conf

# Then reload
sudo sysctl -p
```

### Revert to Original Settings

```bash
# Restore backup
sudo cp /etc/sysctl.conf.backup.* /etc/sysctl.conf

# Reload
sudo sysctl -p
```

### Custom Port Ranges

During installation, choose "custom port range" option:

```
Open custom port range? [y/N]: y
Enter start port: 10000
Enter end port: 10100
```

This opens ports 10000-10100 (TCP/UDP).

---

## 🛠️ Troubleshooting

### Problem: Locked out of SSH

**Prevention:** The script ALWAYS keeps SSH open automatically.

**Solution (if it happens):**
1. Access via VPS provider's console/VNC
2. Run: `sudo ufw allow 22/tcp`
3. Or disable UFW: `sudo ufw disable`

### Problem: BBR not enabled

**Check kernel version:**
```bash
uname -r
```

**BBR requires:** Kernel 4.9 or higher

**Solution:** Update kernel or skip BBR optimization

### Problem: Port still blocked

**Check UFW status:**
```bash
sudo ufw status numbered
```

**Open port manually:**
```bash
sudo ufw allow PORT/tcp
sudo ufw allow PORT/udp
```

### Problem: Can't access 3X-UI panel

**Check if port is open:**
```bash
sudo ufw status | grep 2053
```

**Open if needed:**
```bash
sudo ufw allow 2053/tcp
```

**Check if container is running:**
```bash
docker ps | grep 3xui
```

### Problem: Network optimization not applied

**Verify settings:**
```bash
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.default_qdisc
```

**Reload manually:**
```bash
sudo sysctl -p
```

**Check logs:**
```bash
cat /tmp/.3xui_install_logs_*.txt | grep NETWORK
```

---

## 🔐 Security Best Practices

### ✅ Recommended Setup

1. **Enable UFW firewall** ✓
2. **Apply network optimizations** ✓
3. **Only open required ports** ✓
4. **Use strong admin passwords** ✓
5. **Change default SSH port** (optional but recommended)
6. **Use key-based SSH authentication** (recommended)
7. **Enable fail2ban** (optional)

### ⚠️ Important Notes

1. **Never block SSH** - The script prevents this, but be careful with manual changes
2. **Cloud provider firewalls** - Some VPS providers (AWS, GCP, Azure) have external firewalls that also need configuration
3. **Port conflicts** - Ensure ports aren't already in use before opening
4. **Backup before changes** - All scripts create backups automatically
5. **Test after changes** - Verify you can still access your services

---

## 📚 Technical Details

### Applied sysctl Settings

```bash
# Congestion Control
net.core.default_qdisc=fq                    # Fair Queue
net.ipv4.tcp_congestion_control=bbr          # BBR Algorithm

# TCP Performance
net.ipv4.tcp_fastopen=3                      # Enable TFO
net.ipv4.tcp_mtu_probing=1                   # Dynamic MTU
net.ipv4.tcp_window_scaling=1                # Window scaling
net.ipv4.tcp_slow_start_after_idle=0         # Disable slow start

# Connection Handling
net.core.somaxconn=65535                     # Max listen queue
net.ipv4.tcp_max_syn_backlog=65535          # SYN backlog
net.ipv4.tcp_fin_timeout=15                  # FIN timeout
net.ipv4.tcp_tw_reuse=1                      # TIME_WAIT reuse
net.core.netdev_max_backlog=4096            # RX backlog

# IP Forwarding
net.ipv4.ip_forward=1                        # IPv4 forwarding
net.ipv6.conf.all.forwarding=1              # IPv6 forwarding

# Buffer Sizes (64 MB max)
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
```

### UFW Configuration Files

- **Rules:** `/etc/ufw/user.rules`
- **Sysctl:** `/etc/ufw/sysctl.conf`
- **Config:** `/etc/ufw/ufw.conf`
- **Before rules:** `/etc/ufw/before.rules`

---

## 🆘 Support

If you encounter issues:

1. **Check logs:** `/tmp/.3xui_install_logs_*.txt`
2. **Verify settings:** Use commands in "Check Current Settings" section
3. **Review documentation:** This guide and VPS_Speed_Security_Optimization_Notes.md
4. **Check firewall:** `sudo ufw status verbose`
5. **Test network:** `sysctl net.ipv4.tcp_congestion_control`

---

## 📝 Summary

### What You Get

✅ **Automatic port detection** - No manual configuration needed  
✅ **SSH safety** - Never locks you out  
✅ **BBR enabled** - Dramatically faster speeds  
✅ **Optimized TCP** - Better throughput and latency  
✅ **Secure firewall** - Only required ports open  
✅ **IP forwarding** - Proper VPN/proxy functionality  
✅ **Comprehensive logging** - Track all changes  
✅ **Easy management** - Simple commands for adjustments  

### Expected Results

🚀 **20-30x faster** VPN/proxy speeds  
🛡️ **Secure by default** - Only necessary ports open  
⚡ **Lower latency** - Better connection quality  
📈 **Higher throughput** - Better bandwidth utilization  
🔒 **Protected server** - Firewall blocks unwanted traffic  

---

**Version:** 2.1  
**Last Updated:** November 13, 2025  
**Modules:** `firewall.sh`, `network_optimization.sh`
