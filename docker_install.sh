#!/usr/bin/env bash

#ANSII colors
NC="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
BLUE="\033[34m"

printf %b "${RED} Getting rid of existing packages...\n${NC}"

for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    printf %b "${RED}Removing ${BLUE}$pkg${NC}\n"
    sudo apt-get remove $pkg -y
done

printf %b "${GREEN}DONE!${NC}\n"

# Official Docker install script
sudo apt-get update
printf %b "${BLUE} Installing \"ca-certificates\" and \"curl\"\n"
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
printf %b "${BLUE}Adding the repository to APT sources${NC}\n"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Installation
printf %b "${BLUE}Installing DOCKER${NC}\n"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if [ $? -ne 0 ]; then
    exit 1
fi

printf %b "${GREEN}DONE!!!${NC}\n"
sudo usermod -aG docker $USER
printf %b "${BLUE}Testing docker${NC}\n"
if ! systemctl is-active --quiet docker; then
    printf "%b" "${RED}DOCKER is NOT running\n${NC}"
    sudo systemctl start docker
else
    printf "%b" "${GREEN}Docker is running${NC}\n"
fi

sudo docker run --rm hello-world >/dev/null 2>&1 && \
  printf "%b" "${GREEN}Docker test passed!${NC}\n"

printf %b "${GREEN}DOCKER INSTALLATION SCRIPT OUT!${NC}\n"
