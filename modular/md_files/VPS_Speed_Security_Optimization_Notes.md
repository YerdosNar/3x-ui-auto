# ⚡ VPS Network Speed & Security Optimization Notes
*(for VPN / Shadowsocks / VLESS servers)*

---

## 🧱 Overview
Goal: Maximize throughput and stability between VPS and clients using kernel-level tuning and UFW firewall hardening.

---

## ⚙️ 1. `/etc/sysctl.conf` — Network Optimization
We modified kernel parameters to improve packet handling, TCP behavior, and enable Google BBR congestion control.

```bash
# --- General performance ---
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr     # Enable BBR algorithm for better throughput and lower latency
net.ipv4.tcp_fastopen=3                 # Enable TCP Fast Open (client/server)
net.ipv4.tcp_mtu_probing=1              # Dynamically adjust MTU for unstable networks
net.ipv4.ip_forward=1                   # Allow packet forwarding (needed for VPN/Proxy)
net.ipv6.conf.all.forwarding=1          # Enable forwarding for IPv6 as well

# --- Connection handling ---
net.core.somaxconn=65535                # Max connections in listen queue
net.ipv4.tcp_max_syn_backlog=65535      # Max queued connection requests
net.ipv4.tcp_fin_timeout=15             # Faster cleanup of closed connections
net.ipv4.tcp_tw_reuse=1                 # Reuse TIME_WAIT sockets safely
net.ipv4.tcp_window_scaling=1           # Enable TCP window scaling for large transfers
net.core.netdev_max_backlog=4096        # Max packets queued when interface receives data faster than kernel can process

# --- Buffer sizes ---
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864

# --- Disable slow TCP features ---
net.ipv4.tcp_slow_start_after_idle=0
```

### ✅ Effects
- **BBR** drastically improved TCP efficiency for long-distance or high-latency connections.
- **FQ (Fair Queueing)** ensured fair packet scheduling and reduced latency spikes.
- **Buffer & backlog tuning** prevented packet drops under high load.
- **Fast open** and **reuse** improved connection startup and recycling.

### 🧩 Verification
```bash
sysctl net.ipv4.tcp_congestion_control
# → should print: bbr
```

---

## 🔒 2. UFW Firewall Configuration
Firewall rules restrict access only to required ports while allowing Shadowsocks/VLESS traffic.

### Base Rules
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow 22/tcp       # SSH
sudo ufw allow 80           # HTTP (Caddy)
sudo ufw allow 443          # HTTPS (Caddy)
sudo ufw allow 2087/tcp     # 3X-UI admin panel via Caddy reverse proxy

sudo ufw allow 8380:8400/tcp
sudo ufw allow 8380:8400/udp
sudo ufw allow 8443/tcp
sudo ufw allow 8443/udp
sudo ufw allow 9380:9400/tcp
sudo ufw allow 9380:9400/udp

sudo ufw enable
```

### Enable Packet Forwarding
Edit `/etc/ufw/sysctl.conf`:
```bash
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
```

Check:
```bash
sysctl net.ipv4.ip_forward
# → 1
```

When adding new users/inbounds:
```bash
sudo ufw allow <port>/tcp
sudo ufw allow <port>/udp
```

---

## 📊 3. Results

| Metric | Before | After Optimization |
|:--|:--:|:--:|
| VPS baseline speed | 190 ↓ / 150 ↑ | — |
| Shadowsocks (xchacha20) | 5 ↓ / ~5 ↑ | **170 ↓ / 40 ↑** |
| VLESS | 5 ↓ / 5 ↑ | **150 ↓ / 10 ↑** |

---

## 🧠 4. Summary of What Improved Speed & Security
| Area | Change | Purpose |
|------|---------|----------|
| **TCP congestion control** | Enabled **BBR** | Smarter bandwidth use, higher throughput |
| **Queue discipline** | Switched to `fq` | Fair packet scheduling |
| **Buffer tuning** | Increased send/receive limits | Prevents packet loss under high traffic |
| **Fast open & reuse** | `tcp_fastopen`, `tcp_tw_reuse` | Faster connection setup |
| **UFW tuning** | Strict inbound, open outbound | Secure & stable routing |
| **Forwarding enabled** | `ip_forward=1` | Allow Shadowsocks/VPN traffic |

---
