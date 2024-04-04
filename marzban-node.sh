#!/bin/bash

echo "Running this script will remove the older installation and directories of Marzban-node for the specified panel!!"

read -rp "Do you want to continue? (Y/n): " consent

case "$consent" in
    [Yy]* ) 
        echo "Proceeding with the script..."
        ;;
    [Nn]* ) 
        echo "Script terminated by the user."
        exit 0
        ;;
    * ) 
        echo "Invalid input. Script will exit."
        exit 1
        ;;
esac

echo "Set a nickname for your panel (leave blank for a random nickname - not recomended):"
read -r panel
panel=${panel:-node$(openssl rand -hex 1)}
echo "panel set to: $panel"
echo "Removing existing directories and files..."
rm -rf "$HOME/$panel" &> /dev/null
sudo rm -rf /var/lib/marzban-node/$panel.pem &> /dev/null
sudo rm -rf /var/lib/marzban-node/$panel-core &> /dev/null

echo "Installing necessary packages..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install curl socat git wget unzip -y
trap 'echo "Ctrl+C was pressed but the script will continue."' SIGINT
curl -fsSL https://get.docker.com | sh || { echo "Something went wrong! did you interupt the docker update? then no problem - Are you trying to install Docker on an IR server? try setting DNS."; }
trap - SIGINT
echo "checking if Docker is installed..."
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, please install Docker."
    exit 1
fi
clear

echo "Fetching node files..."
sudo mkdir -p $HOME/$panel
sudo mkdir -p /var/lib/marzban-node
wget -O $HOME/$panel/docker-compose.yml  https://raw.githubusercontent.com/Gozargah/Marzban-node/master/docker-compose.yml
wget -O $HOME/$panel/.env https://raw.githubusercontent.com/Gozargah/Marzban-node/master/.env.example




#choosing core version

echo "which version of xray core do you want? (leave blank for latest)"
read -r core
core=${core:-latest}

cd "/var/lib/marzban-node/"

if [ "$core" == "latest" ]; then
    wget -O Xray-linux-64.zip $(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep browser_download_url | grep 'Xray-linux-64.zip' | cut -d '"' -f 4)
else
    wget -O Xray-linux-64.zip "https://github.com/XTLS/Xray-core/releases/download/v$core/Xray-linux-64.zip" || { 
        echo "Failed to download Xray-core. Are you sure this is the correct version? Check for typos."; 
        exit 1;
    }
fi
if unzip Xray-linux-64.zip; then
    rm Xray-linux-64.zip
    rm geosite.dat
    rm geoip.dat
    rm LICENSE
    rm README.md
    mv xray "$panel-core"
else
    echo "Failed to unzip Xray-linux-64.zip."
    exit 1;  
fi


echo "Success! Now get ready for setup."

while true; do
    echo "Enter the SERVICE PORT value (default 62050):"
    read -r service
    service=${service:-62050}  
    if [[ $service =~ ^[0-9]+$ ]] && [ $service -ge 1 ] && [ $service -le 65535 ]; then
        break 
    else
        echo "Invalid input. Please enter a valid port number between 1 and 65535."
    fi
done


while true; do
    echo "Enter the XRAY API PORT value (default 62051):"
    read -r api
    api=${api:-62051}
    if [[ $api =~ ^[0-9]+$ ]] && [ $api -ge 1 ] && [ $api -le 65535 ]; then
        break  
    else
        echo "Invalid input. Please enter a valid port number between 1 and 65535."
    fi
done

ENV="$HOME/$panel/.env"

#setting up env
sed -i "s|^SERVICE_PORT = .*|SERVICE_PORT = $service|" "$ENV"
sed -i "s|^XRAY_API_PORT = .*|XRAY_API_PORT = $api|" "$ENV"
# Commented because of an issue with node environment
sed -i "s|^# XRAY_EXECUTABLE_PATH = .*|XRAY_EXECUTABLE_PATH = /var/lib/marzban-node/$panel-core|" "$ENV"
sed -i "s|^SSL_CERT_FILE = .*|# SSL_CERT_FILE = /var/lib/marzban-node/ssl_cert.pem|" "$ENV"
sed -i "s|^SSL_KEY_FILE = .*|# SSL_KEY_FILE = /var/lib/marzban-node/ssl_key.pem|" "$ENV"
sed -i "s|^SSL_CLIENT_CERT_FILE = .*|SSL_CLIENT_CERT_FILE = /var/lib/marzban-node/$panel.pem|" "$ENV"
sed -i "s|^# SERVICE_PROTOCOL = rpyc|SERVICE_PROTOCOL = rest|" "$ENV"

echo ".env is ready! Almost done."
echo "Please paste the content of the Client Certificate, then type 'END' on a new line when finished:"

cert=""
while IFS= read -r line
do
    if [[ $line == "END" ]]; then
        break
    fi
    cert+="$line\n"
done

echo -e "$cert" | sudo tee /var/lib/marzban-node/$panel.pem > /dev/null

echo "Certificate is ready, starting the container..."
cd "$HOME/$panel" || { echo "Something went wrong! couldnt enter $panel directory"; exit 1;}
docker compose up -d --remove-orphans
