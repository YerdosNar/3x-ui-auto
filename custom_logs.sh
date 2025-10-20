#!/usr/bin/env bash

install_dir="$HOME/TEMP_3X_INSTALLER_DIR_$$"
mkdir "$install_dir"
git clone https://github.com/YerdosNar/3x-ui-auto.git "$install_dir"
cd $install_dir/modular
chmod +x install.sh
chmod +x functions/*.sh

read -p "Start installation process [Y/n]: " start_install
start_install=${start_install:-Y}
if [[ "$start_install" =~ ^[Yy]$ ]]; then
    ./install.sh
else
    echo "Exit..."
    exit 0
fi

if [ "$?" == '0' ]; then
    echo
    read -p "Remove temporal directory with source code [Y/n]: " remove_choice
    remove_choice=${remove_choice:-Y}
    if [[ "$remove_choice" =~ ^[Yy]$ ]]; then
        echo "Removing directory..."
        cd ~
        rm -rf $install_dir
    else
        echo "Exiting..."
        exit 0
    fi
else
    echo "Installation failed..."
    echo 'Check log files "/tmp/.3xui_install_logs_$$.txt" for troubleshooting.'
fi
