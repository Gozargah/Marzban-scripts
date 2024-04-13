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







echo "Which version of Xray-core do you want?(exmp: 1.8.8)(leave blank for latest)"
read -r version
version=${version:-latest}

# Function to download XRay based on CPU architecture
architecture() {
  local arch
  case "$(uname -m)" in
    'i386' | 'i686')
      arch='32'
      ;;
    'amd64' | 'x86_64')
      arch='64'
      ;;
    'armv5tel')
      arch='arm32-v5'
      ;;
    'armv6l')
      arch='arm32-v6'
      grep Features /proc/cpuinfo | grep -qw 'vfp' || arch='arm32-v5'
      ;;
    'armv7' | 'armv7l')
      arch='arm32-v7a'
      grep Features /proc/cpuinfo | grep -qw 'vfp' || arch='arm32-v5'
      ;;
    'armv8' | 'aarch64')
      arch='arm64-v8a'
      ;;
    'mips')
      arch='mips32'
      ;;
    'mipsle')
      arch='mips32le'
      ;;
    'mips64')
      arch='mips64'
      lscpu | grep -q "Little Endian" && arch='mips64le'
      ;;
    'mips64le')
      arch='mips64le'
      ;;
    'ppc64')
      arch='ppc64'
      ;;
    'ppc64le')
      arch='ppc64le'
      ;;
    'riscv64')
      arch='riscv64'
      ;;
    's390x')
      arch='s390x'
      ;;
    *)
      echo "error: The architecture is not supported."
      return 1
      ;;
  esac
  echo "$arch"
}
arch=$(architecture)
cd "/var/lib/marzban-node/"
if [[ $version == "latest" ]]; then
    wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$arch.zip"
else
    wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/v$version/Xray-linux-$arch.zip"
fi



if unzip xray.zip; then
    rm xray.zip
    rm -v geosite.dat geoip.dat LICENSE README.md
    mv -v xray "$panel-core"
else
    echo "Failed to unzip xray.zip."
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
sudo mkdir -p $HOME/$panel
sudo mkdir -p /var/lib/marzban-node
# echo "Fetching node files..."
# wget -O $HOME/$panel/docker-compose.yml  https://raw.githubusercontent.com/Gozargah/Marzban-node/master/docker-compose.yml
# wget -O $HOME/$panel/.env https://raw.githubusercontent.com/Gozargah/Marzban-node/master/.env.example
ENV="$HOME/$panel/.env"
DOCKER="$HOME/$panel/docker-compose.yml"
#setting up env
cat << EOF > "$ENV"
SERVICE_PORT = $service
XRAY_API_PORT = $api
XRAY_EXECUTABLE_PATH = /var/lib/marzban-node/$panel-core
SSL_CLIENT_CERT_FILE = /var/lib/marzban-node/$panel.pem
SERVICE_PROTOCOL = rest
EOF

echo ".env file has been created successfully."

#setting up docker


to the file
cat << 'EOF' > $DOCKER
services:
  marzban-node:

    image: gozargah/marzban-node:latest
    restart: always
    network_mode: host
    env_file: .env
    volumes:
      - /var/lib/marzban-node:/var/lib/marzban-node
EOF

echo "docker-compose.yml has been created successfully."

echo "Please paste the content of the Client Certificate, press ENTER on a new line when finished:"

cert=""
while IFS= read -r line
do
    if [[ -z $line ]]; then
        break
    fi
    cert+="$line\n"
done


echo -e "$cert" | sudo tee /var/lib/marzban-node/$panel.pem > /dev/null

echo "Certificate is ready, starting the container..."
cd "$HOME/$panel" || { echo "Something went wrong! couldnt enter $panel directory"; exit 1;}
docker compose up -d --remove-orphans
