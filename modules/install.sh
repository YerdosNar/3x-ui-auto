#!/usr/bin/env bash

#ANSII colors
NC="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"

# Change mods
chmod +x configure_caddy.sh
chmod +x docker_install.sh
chmod +x caddy_install.sh
chmod +x create_compose.sh

printf %b "${GREEN}Before we proceed, please enter your password: "
sudo -v || { printf %b "${RED}Wrong!!! Try running this script again\n${NC}"; exit 1; }

printf %b "${BLUE}DOCKER INSTALLATION SCRIPT IN${NC}\n"
./docker_install.sh

printf %b "${BLUE}Creating directory for 3X-UI\n3x-uiPANEL${NC}\n"
mkdir 3x-uiPANEL && cd 3x-uiPANEL

read -p "${BLUE}Do you have a domain name [${GREEN}y${NC}|${RED}n${NC}]: " DN_EXIST

if [[ "$DN_EXIST" == "y" || "$DN_EXIST" == "Y" ]]; then
    DN_EXIST="y"
    read -p "${BLUE}Enter your domain name: " DOM_NAME

    ./create_compose.yml "$DOM_NAME"
else
    # no change to compose.yml
    printf %b "${BLUE}Then I will take your PUBLIC IP.\n${NC}"
    PUB_IP=$(curl ifconfig.me)
    ./create_compose.sh
fi
printf %b "${GREEN}COMPOSE FILE CREATED!\n${NC}"

printf %b "${BLUE}Attempt to run DOCKER${NC}\n"
if ! docker compose up -d; then
    printf %b "${RED}DOCKER COMPOSE didn't run...\n${NC}"
    exit 1
fi

printf %b "${GREEN}DONE!\n"
if [ "$DN_EXIST" == "y" ]; then
    printf %b "Open URL: ${BLUE}http://$DOM_NAME:2053\n"
else
    printf %b "Open URL: ${BLUE}http://$PUB_IP:2053\n"
fi

printf %b "Username: ${BLUE}admin\n${GREEN}Password: ${BLUE}admin\n"

if [ "$DN_EXIST" == "y" ]; then
    read -p "${BLUE}Do you want to Caddy for Reverse Proxy [${GREEN}Y${NC}/${RED}n]${NC}" Y_N
    Y_N=${Y_N:-y}
    if [[ "$Y_N" == "Y" || "$Y_N" == "y" ]]; then
        echo "CADDY INSTALLATION SCRIPT IN..."
        ./caddy_install.sh $DOM_NAME
        if [ $? -ne 0 ]; then
            printf %b "${RED}Could not install Caddy...${NC}\n"
            printf %b "${BLUE}Try another way${NC}\n"
            # TODO: Handle this case by using NGINX or just provide with documentation
            exit 1
        fi
    fi
else
    printf %b "${RED}Your website will NOT be SECURE${NC}\n"
fi

printf %b "${GREEN}FINALLY DONE!${NC}\n"
