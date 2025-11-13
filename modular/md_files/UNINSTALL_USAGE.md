# 3X-UI Uninstaller Usage Guide

## Overview

The uninstall script now supports multiple installations and can be run in various modes.

## Current Behavior

- **Only removes ONE directory at a time** (not all directories)
- Detects all `3x-uiPANEL*` directories (including PID-based names)
- Supports command-line arguments for automation
- Still requires confirmation before deleting

---

## Usage Examples

### 1. **Interactive Mode** (Default)
Prompts you to select which directory to remove if multiple exist:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh)
```

### 2. **List Available Installations**
See all 3X-UI directories without running the uninstall:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -l
```

Example output:
```
Found 3 3X-UI installation director(y/ies):

  1) /home/user/3x-uiPANEL_1234
     Status: Running (Container: 3xui_app_1234)
  2) /home/user/3x-uiPANEL_4321
     Status: Stopped (Container: 3xui_app_4321)
  3) /home/user/3x-uiPANEL_9999
     Status: Running (Container: 3xui_app_9999)

Use -d NUM to select which directory to uninstall.
```

### 3. **Preselect Directory** (Non-Interactive)
Specify which directory to remove (useful for automation):

```bash
# Remove the 2nd directory (3x-uiPANEL_4321 from the example above)
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -d 2
```

### 4. **Local Execution**

```bash
# Interactive
./uninstall.sh

# List directories
./uninstall.sh -l

# Preselect directory
./uninstall.sh -d 1
```

### 5. **Show Help**

```bash
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -h
```

---

## Command-Line Options

| Option | Description |
|--------|-------------|
| `-d NUM` or `--dir NUM` | Select directory number to uninstall (if multiple exist) |
| `-l` or `--list` | List all 3X-UI installation directories and exit |
| `-h` or `--help` | Show help message |

---

## Scenario Examples

### Scenario 1: You have multiple installations and want to remove a specific one

```bash
# Step 1: List all installations
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -l

# Output shows:
#   1) /home/user/3x-uiPANEL_1234
#   2) /home/user/3x-uiPANEL_4321
#   3) /home/user/3x-uiPANEL_9999

# Step 2: Remove directory #2
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -d 2
```

### Scenario 2: You're automating the uninstall in a script

```bash
#!/bin/bash
# Always remove the first installation found
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -d 1
```

### Scenario 3: You want to remove ALL installations one by one

```bash
# Run this command multiple times until no directories remain
bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/uninstall.sh) -d 1
```

---

## What Gets Detected and Removed

### Directories
- `3x-uiPANEL` (legacy, no PID)
- `3x-uiPANEL_1234` (PID-based)
- `3x-uiPANEL_*` (any PID variant)

### Docker Containers
- `3xui_app` (legacy)
- `3xui_app_1234` (PID-based)
- Any container with "3xui" in the name

### Additional Components
- Docker images: `3x-ui:*`
- Caddy web server
- Docker Engine (optional)
- Related configurations and data

---

## Important Notes

1. **Single Directory Removal**: The script only removes ONE directory per run
2. **Confirmation Required**: You still need to confirm deletion with "yes" and "DELETE EVERYTHING"
3. **Container Cleanup**: All 3xui containers are removed regardless of naming
4. **State File**: The script checks `/tmp/.3xui_install_state` for saved installation info
5. **Multiple Installations**: If you have multiple installations, run the script multiple times or use `-d` option

---

## Safety Features

✅ Asks for double confirmation before deleting
✅ Shows directory contents before deletion
✅ Lists Docker resources before removal
✅ Countdown timer before starting uninstall
✅ Option to skip directory/data deletion
✅ Detailed summary of what was removed

---

## Troubleshooting

**Q: The script doesn't find my installation**
A: Make sure your directory starts with `3x-uiPANEL` (check with `ls -la ~/3x-uiPANEL*`)

**Q: I want to remove all installations at once**
A: Currently not supported for safety. Run the script multiple times with `-d 1`

**Q: Can I cancel during uninstall?**
A: Yes! Press Ctrl+C during the countdown or answer "NO" to confirmation prompts

**Q: What if I only want to remove Docker containers, not the directory?**
A: The script asks separately for directory deletion - answer "N" when prompted

---

## Version History

- **v1.1** (2025-11-12): Added PID-based directory detection, command-line arguments, and list mode
- **v1.0**: Initial release with basic uninstall functionality
