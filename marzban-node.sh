#!/bin/bash

echo "Running this script will remove the older default installation and directories of Marzban-node!!"

read -rp "Do you want to continue? (Y/n): " consent

case "$consent" in
    [Yy]* ) 
        echo "Proceeding with the script..."
        ;;
    [Nn]* ) 
        echo "Script terminated by the user."
        exit
        ;;
    * ) 
        echo "Invalid input. Script will exit."
        exit
        ;;
esac

echo "Removing existing directories..."
rm -rf "$HOME/Marzban-node"
sudo rm -rf /var/lib/marzban-node

echo "Installing necessary packages..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install curl socat git -y
trap 'echo "Ctrl+C was pressed but the script will continue."' SIGINT
curl -fsSL https://get.docker.com | sh || { echo "Something went wrong! did you interupt the docker update? then no problem - Are you trying to install Docker on an IR server? try setting DNS."; }
trap - SIGINT
echo "checking if Docker is installed..."
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, please install Docker."
    exit
fi
clear

echo "Cloning Marzban node..."
git clone https://github.com/Gozargah/Marzban-node "$HOME/Marzban-node"
sudo mkdir /var/lib/marzban-node
cp "$HOME/Marzban-node/.env.example" "$HOME/Marzban-node/.env"

echo "Success! Now get ready for setup."
echo "Enter the SERVICE PORT value (default 62050):"
read -r service
echo "Enter the XRAY API PORT value (default 62051):"
read -r api

ENV="$HOME/Marzban-node/.env"

# Update the SERVICE_PORT and XRAY_API_PORT, and comment out the SSL lines
sed -i "s/^SERVICE_PORT = .*/SERVICE_PORT = $service/" "$ENV"
sed -i "s/^XRAY_API_PORT = .*/XRAY_API_PORT = $api/" "$ENV"
sed -i "s/^SSL_CERT_FILE = .*/# SSL_CERT_FILE = \/var\/lib\/marzban-node\/ssl_cert.pem/" "$ENV"
sed -i "s/^SSL_KEY_FILE = .*/# SSL_KEY_FILE = \/var\/lib\/marzban-node\/ssl_key.pem/" "$ENV"
sed -i "s/^# SERVICE_PROTOCOL = rpyc/SERVICE_PROTOCOL = rest/" "$ENV"

echo ".env is ready! Almost done."
echo "Please paste the content of the Client Certificate, then type 'END' on a new line when finished:"

cert=""
while IFS= read -r line
do
    if [[ $line == "END" ]]; then
        break
    fi
    cert+="$line"
done

echo "$cert" | sudo tee /var/lib/marzban-node/ssl_client_cert.pem > /dev/null

echo "Certificate is ready, starting the container..."
cd "$HOME/Marzban-node" || exit
docker compose up -d --remove-orphans
