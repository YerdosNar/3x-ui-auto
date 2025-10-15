#!/usr/bin/env bash

DOM_NAME=$1

printf %b "${BLUE}Making directory for CADDY${NC}\nIn: /var/lib/ /var/log/"
sudo mkdir -p /var/lib/caddy /var/log/caddy
printf %b "${BLUE}Changing owner of the directory${NC}\n"
sudo chown -R caddy:caddy /var/lib/caddy /var/log/caddy
printf %b "${BLUE}Changing mode of the directory${NC}\n"
sudo chmod -R 755 /var/lib/caddy /var/log/caddy

printf %b "${BLUE}Installing necessary packages${NC}\n"
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list
printf %b "${BLUE}Updating${NC}\n"
sudo apt update
printf %b "${BLUE}Installing CADDY${NC}\n"
sudo apt install caddy

printf %b "${GREEN}Installation finished!!!${NC}\n"

printf %b "${BLUE}Let's configure your ${GREEN}CADDYFILE${NC}\n"

read -p "${BLUE}Enter your ADMIN_NAME: ${NC}" ADMIN_NAME
read -p "${BLUE}Enter your PASSWORD  : ${NC}" PASSWORD
HASH_PW=$(caddy hash-password --plaintext "$PASSWORD")

read -p "${BLUE}Enter nickname: " N_NAME
ROUTE="$N_NAME-admin*"

read -p "${BLUE}Enter any port number except for (22,80,443)reverse_proxy[default=8443] : " PORT
PORT=${PORT:-8443}
read -p "${BLUE}Enter any port number except for (22,80,443,$PORT)backend[default=65535]: " BE_PORT
BE_PORT=${BE_PORT:-65535}

chmod +x configure_caddy.sh
./configure_caddy.sh "$DOM_NAME" "$ROUTE" "$ADMIN_NAME" "$HASH_PW" "$PORT" "$BE_PORT"

sudo caddy validate --config Caddyfile | grep "Valid configuration" || { printf %b "${RED}I don't know why it is invalid${NC}\n" && exit 1 }

sudo cp Caddyfile /etc/caddy/Caddyfile

sudo systemctl start caddy
sudo systemctl enable --now caddy
if ! systemctl is-active --quiet caddy; then
    printf %b "${RED}Something went wrong...${NC}\n"
    exit 1
fi

printf %b "${GREEN}DONE!!!\n"
printf %b "${GREEN}HTTPS available!${NC}\n"
printf %b "${BLUE}URL     : ${GREEN}https://$DOM_NAME${NC}\n"
printf %b "${BLUE}Admin   : ${GREEN}$ADMIN_NAME${NC}\n"
printf %b "${BLUE}Password: ${GREEN}$PASSWORD${NC}\n"

printf %b "${BLUE}After you pass WebAuth\n"
printf %b "${BLUE}Admin   : ${GREEN}admin${NC}\n"
printf %b "${BLUE}Password: ${GREEN}admin${NC}\n"
printf %b "${BLUE}CADDY INSTALLATION OUT${NC}\n"
