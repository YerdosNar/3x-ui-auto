# Project Structure Documentation

## 📂 Complete Directory Layout

```
3x-ui-auto/
│
├── install.sh                 # Main entry point - orchestrates installation
│
├── functions/                 # Modular function library
│   │
│   ├── logger.sh             # Logging System Module
│   │   ├── Log initialization
│   │   ├── Console output (colored)
│   │   ├── File output (detailed)
│   │   ├── log_info()
│   │   ├── log_success()
│   │   ├── log_warn()
│   │   ├── log_error()
│   │   ├── log_banner()
│   │   └── exec_silent()     # Run commands with logging only
│   │
│   ├── config.sh             # Configuration & State Management
│   │   ├── STATE_FILE definition
│   │   ├── INSTALL_DIR definition
│   │   ├── save_state()      # Save installation progress
│   │   ├── load_state()      # Resume interrupted installation
│   │   └── clear_state()     # Clean up state files
│   │
│   ├── validators.sh         # Input Validation Functions
│   │   ├── validate_domain()
│   │   ├── validate_port()
│   │   └── check_port_available()
│   │
│   ├── utils.sh              # Utility Helper Functions
│   │   ├── generate_strong_password()
│   │   └── get_public_ip()
│   │
│   ├── requirements.sh       # System Prerequisites Check
│   │   └── check_requirements()
│   │       ├── Root user check
│   │       ├── Sudo access check
│   │       ├── OS compatibility check
│   │       ├── Disk space check
│   │       └── Required commands check
│   │
│   ├── docker.sh             # Docker Installation Module
│   │   └── docker_install()
│   │       ├── Check existing installation
│   │       ├── Remove old packages
│   │       ├── Setup Docker repository
│   │       ├── Install Docker & Compose
│   │       ├── Configure Docker service
│   │       ├── Add user to docker group
│   │       ├── Handle logout/reboot
│   │       └── Test Docker installation
│   │
│   ├── compose.sh            # Docker Compose Configuration
│   │   └── create_compose()
│   │       └── Generate compose.yml with:
│   │           ├── 3X-UI container config
│   │           ├── Volume mappings
│   │           ├── Environment variables
│   │           └── Network settings
│   │
│   ├── panel.sh              # 3X-UI Panel Auto-Configuration
│   │   └── configure_3xui_panel()
│   │       ├── Wait for panel ready
│   │       ├── Login with defaults
│   │       ├── Update credentials
│   │       ├── Change port & route
│   │       ├── Restart panel
│   │       └── Verify new configuration
│   │
│   └── caddy.sh              # Caddy Installation & Configuration
│       ├── configure_caddy()
│       │   └── Generate Caddyfile with:
│       │       ├── Domain configuration
│       │       ├── TLS settings
│       │       ├── Security headers
│       │       ├── Admin route with basic auth
│       │       ├── API route
│       │       └── Default 404 response
│       │
│       └── caddy_install()
│           ├── Check existing installation
│           ├── Add Caddy repository
│           ├── Install Caddy
│           ├── Get admin credentials
│           ├── Configure routes & ports
│           ├── Install Caddyfile
│           ├── Validate configuration
│           ├── Start Caddy service
│           └── Auto-configure panel
│
├── README.md                  # User documentation
└── PROJECT_STRUCTURE.md       # This file
```

## 🔄 Installation Flow

```
┌─────────────────────────────────────────────┐
│         User runs ./install.sh              │
└────────────────┬────────────────────────────┘
                 │
                 ├──> Source all function modules
                 │
                 ├──> Initialize logging system
                 │    └─> /tmp/.3xui_install_logs_<PID>.txt
                 │
                 ├──> Check for saved state
                 │    └─> Resume if interrupted
                 │
                 ├──> check_requirements()
                 │    ├─> Verify not root
                 │    ├─> Check sudo access
                 │    ├─> Validate OS
                 │    ├─> Check disk space
                 │    └─> Verify required commands
                 │
                 ├──> docker_install()
                 │    ├─> Check existing Docker
                 │    ├─> Install if needed
                 │    ├─> Handle docker group
                 │    │   ├─> Save state
                 │    │   └─> Logout/Reboot (if needed)
                 │    └─> Test Docker
                 │
                 ├──> Create installation directory
                 │    └─> ~/3x-uiPANEL/
                 │
                 ├──> Domain configuration
                 │    ├─> With domain
                 │    │   └─> create_compose(domain)
                 │    └─> Without domain
                 │        └─> create_compose()
                 │
                 ├──> Start 3X-UI container
                 │    ├─> docker compose up -d
                 │    ├─> Wait for healthy status
                 │    └─> Verify running
                 │
                 ├──> Caddy setup (if domain exists)
                 │    ├─> caddy_install(domain)
                 │    │   ├─> Install Caddy
                 │    │   ├─> Get credentials
                 │    │   ├─> Configure ports
                 │    │   ├─> configure_caddy()
                 │    │   ├─> Validate config
                 │    │   ├─> Start service
                 │    │   └─> configure_3xui_panel()
                 │    │       ├─> Auto-configure (try)
                 │    │       └─> Manual steps (fallback)
                 │    └─> Skip Caddy (optional)
                 │
                 ├──> Display access information
                 │    ├─> Panel URL
                 │    ├─> Credentials
                 │    └─> Useful commands
                 │
                 ├──> Clear state
                 │
                 └──> Installation complete!
```

## 📊 Module Dependencies

```
install.sh
    │
    ├──> logger.sh (required first - used by all)
    │
    ├──> config.sh
    │    └──> Uses: logger.sh
    │
    ├──> validators.sh
    │    └──> Uses: logger.sh
    │
    ├──> utils.sh
    │    └──> Uses: logger.sh
    │
    ├──> requirements.sh
    │    └──> Uses: logger.sh
    │
    ├──> docker.sh
    │    └──>
