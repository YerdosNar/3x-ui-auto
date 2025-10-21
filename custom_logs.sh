#!/usr/bin/env bash

# bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/custom_logs.sh)
# ───────────────────────────────
# ANSI Colors
# ───────────────────────────────
local NC="\033[0m"
local RED="\033[31m"
local GREEN="\033[32m"
local YELLOW="\033[33m"
local BLUE="\033[34m"
local CYAN="\033[36m"
local BOLD="\033[1m"

# ───────────────────────────────
# Logging Functions
# ───────────────────────────────
# ───────────────────────────────
# Start
# ───────────────────────────────
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════"
echo -e "         ✓ 3X-UI Panel (with custom logs)!"
echo -e "═══════════════════════════════════════════════════════════${NC}"
echo -e "This scipt saves logs into ${YELLOW}/tmp/.3xui_install_logs_*.txt${NC}"
echo -e "Press ${YELOW}ENTER${NC} to continue..."
read


# ───────────────────────────────
# Start
# ───────────────────────────────
install_dir="$HOME/TEMP_3X_INSTALLER_DIR_$$"
echo -e "${BLUE}[INFO]${NC} Creating Temporal directory"
mkdir "$install_dir"


# ───────────────────────────────
# Cloning repo
# ───────────────────────────────
echo -e "${BLUE}[INFO]${NC} Cloning into \"$install_dir\""
git clone https://github.com/YerdosNar/3x-ui-auto.git "$install_dir"
cd $install_dir/modular
echo -e "${BLUE}[INFO]${NC} Making scripts executable"
chmod +x install.sh
chmod +x functions/*.sh


# ───────────────────────────────
# Start
# ───────────────────────────────
read -p "Start installation process [Y/n]: " start_install
start_install=${start_install:-Y}
if [[ "$start_install" =~ ^[Yy]$ ]]; then
    ./install.sh
else
    echo "You can start later manually"
    echo -e "Run ${GREEN}install.sh${NC} inside ${GREEN}$install_dir/modular${NC} directory"
    echo -e "${BLUE}[INFO]${NC} Exitting..."
    exit 0
fi

if [ "$?" == '0' ]; then
    echo
    read -p "Remove temporal directory with source code [Y/n]: " remove_choice
    remove_choice=${remove_choice:-Y}
    if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[INFO]${NC} Removing directory..."
        cd $HOME
        rm -rf $install_dir
    else
        echo -e "${BLUE}[INFO]${NC} Exiting..."
        exit 0
    fi
else
    echo -e "${RED}[ERROR]${NC} Installation failed..."
    echo -e "${CYAN}Check log files \"${YELLOW}/tmp/.3xui_install_logs_$$.txt${CYAN}\" for troubleshooting.${NC}"
fi
