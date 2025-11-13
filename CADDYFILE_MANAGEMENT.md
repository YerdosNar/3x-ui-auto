# Caddyfile Management

## Overview

The installation scripts (`one_liner.sh` and `modular/install.sh`) now intelligently handle existing Caddyfile configurations. Instead of blindly overwriting, the scripts will:

1. **Check if Caddyfile exists** at `/etc/caddy/Caddyfile`
2. **Check if your domain is already configured**
3. **Decide whether to append or prompt for action**

---

## Behavior Scenarios

### Scenario 1: No Existing Caddyfile
**Situation:** `/etc/caddy/Caddyfile` does not exist

**Action:**
- Creates a new Caddyfile with your 3X-UI configuration
- No backup needed

**Output:**
```
[INFO] No existing Caddyfile found, creating new one...
[✓]    New Caddyfile created!
```

---

### Scenario 2: Caddyfile Exists, Domain Not Configured
**Situation:** Caddyfile exists but your domain (`example.com`) is not in it

**Action:**
- Creates backup: `/etc/caddy/Caddyfile.backup.<timestamp>`
- Appends your 3X-UI configuration to the existing file
- Preserves all existing configurations

**Output:**
```
[INFO] Existing Caddyfile found at /etc/caddy/Caddyfile
[INFO] Domain not found in existing Caddyfile, appending...
[✓]    Backup created: /etc/caddy/Caddyfile.backup.1731456789
[✓]    Configuration appended to existing Caddyfile!
```

**Example Result:**
```caddyfile
# Existing configuration
oldsite.com {
    reverse_proxy localhost:8080
}

# 3X-UI Configuration for example.com - Added Wed Nov 13 10:30:00 UTC 2025
example.com {
    encode gzip
    
    tls {
        protocols tls1.3
    }
    
    # ... your 3X-UI config
}
```

---

### Scenario 3: Caddyfile Exists, Domain Already Configured
**Situation:** Caddyfile exists and your domain (`example.com`) is already configured

**Action:**
- Prompts you to decide what to do
- Two options:
  - **Overwrite:** Removes old config for that domain, appends new one
  - **Keep:** Saves new config to installation directory only

**Output:**
```
[INFO] Existing Caddyfile found at /etc/caddy/Caddyfile
[!]    Domain example.com already exists in Caddyfile!

Overwrite existing configuration for example.com? [y/N]: 
```

#### Option A: You choose "Yes" (Overwrite)
```
[✓]    Backup created: /etc/caddy/Caddyfile.backup.1731456789
[INFO] Removing old configuration for example.com...
[INFO] Appending new configuration for example.com...
[✓]    Configuration for example.com appended to Caddyfile!
```

#### Option B: You choose "No" (Keep)
```
[!]    Keeping existing configuration. New config saved to: /home/user/3x-uiPANEL/Caddyfile
[!]    You can manually merge configurations if needed.
```

---

## Backup System

### Automatic Backups
Every time the script modifies an existing Caddyfile, it creates a timestamped backup:

```bash
/etc/caddy/Caddyfile.backup.1731456789
/etc/caddy/Caddyfile.backup.1731456890
/etc/caddy/Caddyfile.backup.1731457000
```

### Restoring from Backup
If something goes wrong, restore the backup:

```bash
# List all backups
ls -lh /etc/caddy/Caddyfile.backup.*

# Restore the most recent backup
sudo cp /etc/caddy/Caddyfile.backup.* /etc/caddy/Caddyfile

# Reload Caddy
sudo systemctl reload caddy
```

### Cleaning Old Backups
```bash
# Remove backups older than 7 days
sudo find /etc/caddy -name "Caddyfile.backup.*" -mtime +7 -delete
```

---

## Configuration Validation

Before applying any changes, the script validates the Caddyfile:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

If validation fails:
- Changes are NOT applied to Caddy service
- Error message shows the issue
- Instructions to restore backup are provided

---

## Manual Configuration Management

### View Current Caddyfile
```bash
sudo cat /etc/caddy/Caddyfile
```

### Test Configuration
```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

### Reload Caddy (Apply Changes)
```bash
sudo systemctl reload caddy
```

### Check Caddy Status
```bash
sudo systemctl status caddy
```

### View Caddy Logs
```bash
sudo journalctl -u caddy -f
```

---

## Multiple 3X-UI Installations

You can have multiple 3X-UI installations on different domains:

### Example Setup
```caddyfile
# First installation
panel1.example.com {
    route /admin* {
        basic_auth {
            admin1 $hashed_password1
        }
        reverse_proxy localhost:2087
    }
}

# Second installation
panel2.example.com {
    route /admin* {
        basic_auth {
            admin2 $hashed_password2
        }
        reverse_proxy localhost:3087
    }
}

# Third installation
panel3.example.com {
    route /secure* {
        basic_auth {
            admin3 $hashed_password3
        }
        reverse_proxy localhost:4087
    }
}
```

Each installation:
- Uses a different domain/subdomain
- Has its own admin credentials
- Runs on a different backend port
- Has its own route path

---

## Best Practices

### 1. **Use Different Domains/Subdomains**
✅ Good:
```
panel1.example.com
panel2.example.com
vpn.mysite.com
```

❌ Bad:
```
example.com (used twice)
```

### 2. **Use Different Ports**
✅ Good:
```
Backend Port 1: 2087
Backend Port 2: 3087
Backend Port 3: 4087
```

❌ Bad:
```
Both using: 2087
```

### 3. **Use Different Route Paths**
✅ Good:
```
/admin
/panel
/secure
/v2ray
```

❌ Bad:
```
Both using: /admin
```

### 4. **Regular Backups**
```bash
# Backup before making changes
sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.manual.$(date +%s)
```

### 5. **Test After Changes**
```bash
# Always validate
sudo caddy validate --config /etc/caddy/Caddyfile

# Then reload
sudo systemctl reload caddy
```

---

## Troubleshooting

### Problem: Configuration validation fails
**Solution:**
```bash
# Check syntax errors
sudo caddy validate --config /etc/caddy/Caddyfile

# Restore backup
sudo cp /etc/caddy/Caddyfile.backup.* /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

### Problem: Domain conflict
**Solution:**
- Choose a different domain/subdomain
- Or overwrite the existing configuration when prompted

### Problem: Can't access panel after changes
**Solution:**
```bash
# Check Caddy status
sudo systemctl status caddy

# Check logs
sudo journalctl -u caddy -n 50

# Verify configuration
sudo caddy validate --config /etc/caddy/Caddyfile

# Restore backup if needed
sudo cp /etc/caddy/Caddyfile.backup.* /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

### Problem: Lost backup files
**Solution:**
Backups are in `/etc/caddy/` with pattern `Caddyfile.backup.*`
```bash
ls -lah /etc/caddy/Caddyfile.backup.*
```

---

## Safety Features

✅ **Automatic backups** before any modification  
✅ **Domain conflict detection** to prevent overwrites  
✅ **Configuration validation** before applying  
✅ **User confirmation** for overwriting existing configs  
✅ **Detailed logging** of all changes  
✅ **Rollback instructions** if validation fails  
✅ **Preserves existing configs** when appending  

---

## Version History

- **v2.1** (2025-11-13): Added intelligent Caddyfile management with append/overwrite logic
- **v2.0**: Initial release with basic Caddy support
