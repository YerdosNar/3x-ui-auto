#!/usr/bin/env bash

# bash <(curl -Ls https://raw.githubusercontent.com/YerdosNar/3x-ui-auto/master/custom_logs.sh)
# ───────────────────────────────
# ANSI Colors
# ───────────────────────────────
custom_nc="\033[0m"
custom_red="\033[31m"
custom_green="\033[32m"
custom_yellow="\033[33m"
custom_blue="\033[34m"
custom_cyan="\033[36m"
custom_bold="\033[1m"

# ───────────────────────────────
# Logging Functions
# ───────────────────────────────
# ───────────────────────────────
# Start
# ───────────────────────────────
echo -e "${custom_cyan}${custom_bold}═══════════════════════════════════════════════════════════"
echo -e "         ✓ 3X-UI Panel (with custom logs)!"
echo -e "═══════════════════════════════════════════════════════════${custom_nc}"
echo -e "This scipt saves logs into ${custom_yellow}/tmp/.3xui_install_logs_*.txt${custom_nc}"
echo -e "Press ${custom_yellow}ENTER${custom_nc} to continue..."
read


# ───────────────────────────────
# Start
# ───────────────────────────────
install_dir="$HOME/TEMP_3X_INSTALLER_DIR_$$"
echo -e "${custom_blue}[INFO]${custom_nc} Creating Temporal directory"
mkdir "$install_dir"


# ───────────────────────────────
# Cloning repo
# ───────────────────────────────
echo -e "${custom_blue}[INFO]${custom_nc} Cloning into \"$install_dir\""
git clone https://github.com/YerdosNar/3x-ui-auto.git "$install_dir"
cd $install_dir/modular
echo -e "${custom_blue}[INFO]${custom_nc} Making scripts executable"
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
    echo -e "Run ${custom_green}install.sh${custom_nc} inside ${custom_green}$install_dir/modular${custom_nc} directory"
    echo -e "${custom_blue}[INFO]${custom_nc} Exitting..."
    exit 0
fi

if [ "$?" == '0' ]; then
    echo
    read -p "Remove temporal directory with source code [Y/n]: " remove_choice
    remove_choice=${remove_choice:-Y}
    if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
        echo -e "${custom_blue}[INFO]${custom_nc} Removing directory..."
        cd $HOME
        rm -rf $install_dir
    else
        echo -e "${custom_blue}[INFO]${custom_nc} Exiting..."
        exit 0
    fi
else
    echo -e "${custom_red}[ERROR]${custom_nc} Installation failed..."
    echo -e "${custom_cyan}Check log files \"${custom_yellow}/tmp/.3xui_install_logs_$$.txt${custom_cyan}\" for troubleshooting.${custom_nc}"
fi
