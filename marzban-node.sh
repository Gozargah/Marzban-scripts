#!/bin/bash

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print error message
print_error() {
  echo -e "${RED}$1${NC}"
}

# Function to print success message
print_success() {
  echo -e "${GREEN}$1${NC}"
}

# Function to print info message
print_info() {
  echo -e "${CYAN}$1${NC}"
}

# Running this script will remove the older installation and directories of Marzban-node for the specified panel!!

# Installing necessary packages

print_info "Installing necessary packages..."
print_info "DON’T PANIC IF IT LOOKS STUCK!"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install curl socat git wget unzip -y
trap 'echo "Ctrl+C was pressed but the script will continue."' SIGINT
curl -fsSL https://get.docker.com | sh || { print_error "Something went wrong! Did you interrupt the Docker update? If so, no problem. Are you trying to install Docker on an IR server? Try setting DNS."; }
trap - SIGINT
clear
print_info "Checking if Docker is installed..."
if ! command -v docker &> /dev/null; then
  print_error "Docker could not be found, please install Docker."
  exit 1
else
  print_success "Docker installation found!"
fi

# CPU architecture
architecture() {
  local arch
  case "$(uname -m)" in
    'i386' | 'i686') arch='32' ;;
    'amd64' | 'x86_64') arch='64' ;;
    'armv5tel') arch='arm32-v5' ;;
    'armv6l')
      arch='arm32-v6'
      grep Features /proc/cpuinfo | grep -qw 'vfp' || arch='arm32-v5'
      ;;
    'armv7' | 'armv7l')
      arch='arm32-v7a'
      grep Features /proc/cpuinfo | grep -qw 'vfp' || arch='arm32-v5'
      ;;
    'armv8' | 'aarch64') arch='arm64-v8a' ;;
    'mips') arch='mips32' ;;
    'mipsle') arch='mips32le' ;;
    'mips64')
      arch='mips64'
      lscpu | grep -q "Little Endian" && arch='mips64le'
      ;;
    'mips64le') arch='mips64le' ;;
    'ppc64') arch='ppc64' ;;
    'ppc64le') arch='ppc64le' ;;
    'riscv64') arch='riscv64' ;;
    's390x') arch='s390x' ;;
    *)
      print_error "Error: The architecture is not supported."
      return 1
      ;;
  esac
  echo "$arch"
}
arch=$(architecture)

# Getting info and credentials

# Folder name
print_info "Set a name for node directory (leave blank for a random name - not recommended): "
read -r panel
panel=${panel:-node$(openssl rand -hex 1)}

# Core version
print_info "Which version of Xray-core do you want? (e.g., 1.8.8) (leave blank for latest): "
read -r version
version=${version:-latest}

# Port setup
while true; do
  print_info "Enter the SERVICE PORT value (default 62050): "
  read -r service
  service=${service:-62050}

  print_info "Enter the XRAY API PORT value (default 62051): "
  read -r api
  api=${api:-62051}

  if [[ $service =~ ^[0-9]+$ ]] && [ $service -ge 1 ] && [ $service -le 65535 ] && [[ $api =~ ^[0-9]+$ ]] && [ $api -ge 1 ] && [ $api -le 65535 ]; then
    break
  else
    print_error "Invalid input. Please enter valid port numbers between 1 and 65535."
  fi
done

# Certificate setup
print_info "Please paste the content of the Client Certificate, press ENTER on a new line when finished: "

cert=""
while IFS= read -r line; do
  if [[ -z $line ]]; then
    break
  fi
  cert+="$line\n"
done

# Creating node directory

print_info "Panel set to: $panel"
print_info "Removing existing directories and files..."
rm -rf "$HOME/$panel" &> /dev/null
sudo rm -rf /var/lib/marzban-node/$panel.pem &> /dev/null
sudo rm -rf /var/lib/marzban-node/$panel-core &> /dev/null

# Setting path
sudo mkdir -p /var/lib/marzban-node
cd "/var/lib/marzban-node/"

# Fetching core and setting it up
print_info "Fetching Xray-core version $version..."
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
  print_error "Failed to unzip xray.zip."
  exit 1
fi

print_success "Success! Now get ready for setup."

# ENV and Docker setup
sudo mkdir -p $HOME/$panel

# echo "Fetching node files..."
# wget -O $HOME/$panel/docker-compose.yml  https://raw.githubusercontent.com/Gozargah/Marzban-node/master/docker-compose.yml
# wget -O $HOME/$panel/.env https://raw.githubusercontent.com/Gozargah/Marzban-node/master/.env.example

# Defining path
ENV="$HOME/$panel/.env"
DOCKER="$HOME/$panel/docker-compose.yml"

# Setting up env
cat << EOF > "$ENV"
SERVICE_PORT=$service
XRAY_API_PORT=$api
XRAY_EXECUTABLE_PATH=/var/lib/marzban-node/$panel-core
SSL_CLIENT_CERT_FILE=/var/lib/marzban-node/$panel.pem
SERVICE_PROTOCOL=rest
EOF

print_success ".env file has been created successfully."

# Setting up docker-compose.yml
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

print_success "docker-compose.yml has been created successfully."

echo -e "$cert" | sudo tee /var/lib/marzban-node/$panel.pem > /dev/null

print_success "Certificate is ready, starting the container..."
cd "$HOME/$panel" || { print_error "Something went wrong! Couldn't enter $panel directory"; exit 1; }
docker compose up -d --remove-orphans
