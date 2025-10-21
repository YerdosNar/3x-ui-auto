# 🧩 3X-UI Auto Installer (Docker + Caddy)

This project provides a **one-liner automatic installer** for the [3X-UI panel](https://github.com/mhsanaei/3x-ui) on **Ubuntu** servers.

It installs:
- 🐳 **[Docker & Docker Compose](https://docs.docker.com/engine/install/ubuntu/)**
- 🔒 **[Caddy](https://caddyserver.com/docs/) (Reverse Proxy with HTTPS)**
- ⚙️ **[3X-UI panel](https://github.com/MHSanaei/3x-ui) container automatically configured**

---

## 🚀 Quick Installation

Run this single command on a clean Ubuntu system:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/one_liner.sh)
````

> ⚠️ The script requires `sudo` privileges.
> It will automatically install and configure Docker, 3X-UI, and optionally Caddy for HTTPS access.

---

## 🧠 What This Script Does

1. **Installs Docker and Docker Compose**

   * Removes any old Docker versions
   * Adds the official Docker repository
   * Installs and verifies Docker engine

2. **Deploys the 3X-UI Panel**

   * Creates a `3x-uiPANEL/compose.yml` file
   * Runs the container in host network mode
   * Maps config & certificate folders automatically

3. **Optionally Installs and Configures Caddy**

   * Automatically installs from the official repository
   * Generates a secure `Caddyfile` with HTTPS enabled
   * Sets up Basic Auth for the admin route
   * Configures reverse proxy rules for API and backend

---

## 🌐 Access Information

After installation, the script displays:

| Access Type         | Example URL                  | Default Login           |
| ------------------- | ---------------------------- | ----------------------- |
| Without Domain      | `http://YOUR_SERVER_IP:2053` | `admin / admin`         |
| With Domain + Caddy | `https://yourdomain.com`     | (Your admin + password) |

---

## ⚙️ Optional Configuration Prompts

During installation, you’ll be asked:

* Do you have a domain name? (`y/n`)

  * If yes: enter your domain, and optionally install **Caddy** for HTTPS.
  * If no: script uses your **public IP** instead (HTTP only).

* If installing Caddy, you’ll also set:

  * Admin username & password (used for Basic Auth)
  * Route nickname (e.g., `/mypanel-admin`)
  * Ports for API and backend

---

## 🗂️ Directory Structure

After running, you’ll have:

```
3x-uiPANEL/
├── compose.yml        # Docker Compose configuration
├── db/                # 3X-UI configuration & database
└── cert/              # Certificates for Caddy (if used)
```

---

## 🔍 Commands

| Action          | Command                   |
| --------------- | ------------------------- |
| Start panel     | `docker compose up -d`    |
| Stop panel      | `docker compose down`     |
| View logs       | `docker compose logs -f`  |
| Restart service | `docker restart 3xui_app` |

---

## 🧾 Requirements

* Ubuntu 20.04 or later
* Root or `sudo` privileges
* Internet connection (for downloading Docker & 3X-UI image)

---

## ⚠️ Troubleshooting

* **Docker group permissions**:
  After installation, log out and back in to apply Docker group membership:

  ```bash
  newgrp docker
  ```

* **Port conflicts**:
  Ensure that ports `2053`, `8443`, and `2087` are free.

* **Caddy not starting?**
  Check logs:

  ```bash
  sudo systemctl status caddy -l
  ```

---

## 💡 Example Usage

### Install without a domain (⚠️not secure)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/one_liner.sh)
# -> Select "n" when asked about domain
```

### Install with a domain and HTTPS (secure recommended)

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/one_liner.sh)
# -> Select "y" and provide your domain name
# -> Choose to install Caddy for HTTPS
```
Then you can access your panel at:
```
https://yourdomain.com/admin/
```

---

## 🧰 Uninstallation

To remove everything (including containers and configs):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh)
```
---

## 🧑‍💻 Author

**Yerdos Narzhigitov**
📦 [GitHub: @YerdosNar](https://github.com/YerdosNar)

---

## 🪪 License

This project is released under the [GPL-v3 License](LICENSE) (as the [3X-UI](https://github.com/MHSanaei/3x-ui) project)

---

> 💬 *Contributions, feedback, and pull requests are welcome!*

