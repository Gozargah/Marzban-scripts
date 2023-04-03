#!/bin/bash
set -e

INSTALL_DIR="/opt"
if [ -z "$APP_NAME" ]; then
    APP_NAME="marzban"
fi
APP_DIR="$INSTALL_DIR/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"


colorized_echo() {
    local color=$1
    local text=$2
    
    case $color in
        "red")
        echo -e "\e[91m${text}\e[0m";;
        "green")
        echo -e "\e[92m${text}\e[0m";;
        "yellow")
        echo -e "\e[93m${text}\e[0m";;
        "blue")
        echo -e "\e[94m${text}\e[0m";;
        "magenta")
        echo -e "\e[95m${text}\e[0m";;
        "cyan")
        echo -e "\e[96m${text}\e[0m";;
        *)
            echo "${text}"
        ;;
    esac
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This command must be run as root."
        exit 1
    fi
}

detect_os() {
    # Detect the operating system
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
        elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
        elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
        elif [ -f /etc/arch-release ]; then
        OS="Arch"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
    
}

detect_and_update_package_manager() {
    colorized_echo blue "Updating package manager"
    if [[ "$OS" == "Ubuntu" ]] || [[ "$OS" == "Debian" ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update
        elif [ "$OS" == "CentOS" ]; then
        PKG_MANAGER="yum"
        $PKG_MANAGER update
        elif [ "$OS" == "Fedora" ]; then
        PKG_MANAGER="dnf"
        $PKG_MANAGER update
        elif [ "$OS" == "Arch" ]; then
        PKG_MANAGER="pacman"
        $PKG_MANAGER -Sy
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

detect_compose() {
    # Check if docker compose command exists
    if docker compose >/dev/null 2>&1; then
        COMPOSE='docker compose'
        elif docker-compose >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "docker compose not found"
        exit 1
    fi
}

install_package () {
    if [ -z $PKG_MANAGER ]; then
        detect_and_update_package_manager
    fi
    
    PACKAGE=$1
    colorized_echo blue "Installing $PACKAGE"
    if [[ "$OS" == "Ubuntu" ]] || [[ "$OS" == "Debian" ]]; then
        $PKG_MANAGER -y install "$PACKAGE"
        elif [ "$OS" == "CentOS" ]; then
        $PKG_MANAGER install -y "$PACKAGE"
        elif [ "$OS" == "Fedora" ]; then
        $PKG_MANAGER install -y "$PACKAGE"
        elif [ "$OS" == "Arch" ]; then
        $PKG_MANAGER -S --noconfirm "$PACKAGE"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_docker() {
    # Install Docker and Docker Compose using the official installation script
    colorized_echo blue "Installing Docker"
    curl -fsSL https://get.docker.com | sh
    colorized_echo green "Docker installed successfully"
}

install_marzban() {
    # Fetch releases
    FETCH_REPO="Gozargah/Marzban-examples"
    FETCH_TAG="downloads"
    URL="https://api.github.com/repos/$FETCH_REPO/releases/tags/$FETCH_TAG"
    ASSETS=$(curl -s $URL | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .name | sub("\\.tar\\.gz$";"")')
    if [ -z "$ASSETS" ]; then
        colorized_echo red "No assets found for tag $FETCH_TAG"
        exit 1
    fi
    
    echo
    colorized_echo magenta "Marzban has some pre-built configurations based on different needs that you can choose"
    colorized_echo magenta "See the instructions here for more information: https://github.com/Gozargah/Marzban-examples"
    # Prompt user to select an asset
    PS3="Choose one of the setups: "
    select ASSET in $ASSETS; do
        if [ -n "$ASSET" ]; then
            break
        fi
    done
    
    # Download and extract selected asset to 'marzban' directory
    DOWNLOAD_URL="https://github.com/$FETCH_REPO/releases/download/$FETCH_TAG/$ASSET.tar.gz"
    colorized_echo blue "Downloading $DOWNLOAD_URL and extracting to $APP_DIR"
    curl -sL $DOWNLOAD_URL | tar xz --xform "s/$ASSET/$APP_NAME/" -C $INSTALL_DIR
    colorized_echo green "Marzban files downloaded and extracted successfully"
}

up_marzban() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" up -d --remove-orphans
}

down_marzban() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" down
}

show_marzban_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs
}

follow_marzban_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs -f
}

update_marzban() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" pull
}

is_marzban_installed() {
    if [ -d $APP_DIR ]; then
        return 0
    else
        return 1
    fi
}

is_marzban_up() {
    if [ -z "$($COMPOSE -f $COMPOSE_FILE ps -q -a)" ]; then
        return 1
    else
        return 0
    fi
}

install_acme_sh() {
    # Install required packages
    if ! command -v crontab >/dev/null 2>&1; then
        install_package cron
    fi
    install_package cron
    if ! command -v socat >/dev/null 2>&1; then
        install_package socat
    fi
    
    colorized_echo blue "Installing acme.sh"
    curl https://get.acme.sh | sh
}

ask_for_tls() {
    echo
    read -p "Do you want to enable TLS? (y/n) "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Prompt user for email and domain name
        read -p "Please enter your email address: " EMAIL
        while [[ -z $EMAIL ]]; do
            read -p "Email address cannot be empty. Please enter your email address: " EMAIL
        done
        
        read -p "Please enter your domain name: " DOMAIN_NAME
        while [[ -z $DOMAIN_NAME ]]; do
            read -p "Domain name cannot be empty. Please enter your domain name: " DOMAIN_NAME
        done
        
        if ! command -v ~/.acme.sh/acme.sh >/dev/null 2>&1; then
            install_acme_sh
        fi
        
        # Make a directory to install certs there
        CERTS_DIR=/var/lib/$APP_NAME/certs
        mkdir -p $CERTS_DIR
        
        # Issue certificate
        colorized_echo blue "Issuing certificate for $DOMAIN_NAME"
        ~/.acme.sh/acme.sh --issue --standalone -d $DOMAIN_NAME --force --email $EMAIL --key-file $CERTS_DIR/key.pem --fullchain-file $CERTS_DIR/fullchain.pem
        
        # Update xray config file
        sed -i 's/\"SERVER_NAME\"/'\""$DOMAIN_NAME"\"'/g' $APP_DIR/xray_config.json
        sed -i 's|/var/lib/marzban/certs|'"$CERTS_DIR"'|g' $APP_DIR/xray_config.json
        sed -i 's/\/\/\([^/]\)/\1/g' $APP_DIR/xray_config.json
        
        colorized_echo green "TLS is enabled for $DOMAIN_NAME"
    fi
}

install_command() {
    check_running_as_root
    # Check if marzban is already installed
    if is_marzban_installed; then
        colorized_echo red "Marzban is already installed at $APP_DIR"
        read -p "Do you want to override the previous installation? (y/n) "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo red "Aborted installation"
            exit 1
        fi
    fi
    detect_os
    if ! command -v curl >/dev/null 2>&1; then
        install_package curl
    fi
    if ! command -v jq >/dev/null 2>&1; then
        install_package jq
    fi
    if ! command -v docker >/dev/null 2>&1; then
        install_docker
    fi
    detect_compose
    install_marzban
    ask_for_tls
    up_marzban
    follow_marzban_logs
}

up_command() {
    help() {
        colorized_echo red "Usage: marzban.sh up [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs)
                no_logs=true
            ;;
            -h|--help)
                help
                exit 0
            ;;
            *)
                echo "Error: Invalid option: $1" >&2
                help
                exit 0
            ;;
        esac
        shift
    done
    
    detect_compose
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    if is_marzban_up; then
        colorized_echo red "Marzban's already up"
        exit 1
    fi
    
    up_marzban
    if [ "$no_logs" = false ]; then
        follow_marzban_logs
    fi
}

down_command() {
    detect_compose
    
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    if ! is_marzban_up; then
        colorized_echo red "Marzban's already down"
        exit 1
    fi
    
    down_marzban
}

restart_command() {
    help() {
        colorized_echo red "Usage: marzban.sh restart [options]"
        echo
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs)
                no_logs=true
            ;;
            -h|--help)
                help
                exit 0
            ;;
            *)
                echo "Error: Invalid option: $1" >&2
                help
                exit 0
            ;;
        esac
        shift
    done
    
    detect_compose
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    down_marzban
    up_marzban
    if [ "$no_logs" = false ]; then
        follow_marzban_logs
    fi
}

status_command() {
    detect_compose
    
    # Check if marzban is installed
    if ! is_marzban_installed; then
        echo -n "Status: "
        colorized_echo red "Not Installed"
        exit 1
    fi
    
    if ! is_marzban_up; then
        echo -n "Status: "
        colorized_echo blue "Down"
        exit 1
    fi
    
    echo -n "Status: "
    colorized_echo green "Up"
    
    json=$($COMPOSE -f $COMPOSE_FILE ps -a --format=json)
    services=$(echo $json | jq -r '.[] | .Service')
    states=$(echo $json | jq -r '.[] | .State')
    # Print out the service names and statuses
    for i in $(seq 0 $(expr $(echo $services | wc -w) - 1)); do
        service=$(echo $services | cut -d' ' -f $(expr $i + 1))
        state=$(echo $states | cut -d' ' -f $(expr $i + 1))
        echo -n "- $service: "
        if [ "$state" == "running" ]; then
            colorized_echo green $state
        else
            colorized_echo red $state
        fi
    done
}

logs_command() {
    help() {
        colorized_echo red "Usage: marzban.sh logs [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-follow   do not show follow logs"
    }
    
    local no_follow=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-follow)
                no_follow=true
            ;;
            -h|--help)
                help
                exit 0
            ;;
            *)
                echo "Error: Invalid option: $1" >&2
                help
                exit 0
            ;;
        esac
        shift
    done
    
    detect_compose
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    if ! is_marzban_up; then
        colorized_echo red "Marzban is not up."
        exit 1
    fi
    
    if [ "$no_follow" = true ]; then
        show_marzban_logs
    else
        follow_marzban_logs
    fi
}

update_command() {
    detect_compose
    
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi
    
    colorized_echo blue "Pulling latest version"
    update_marzban
    
    colorized_echo blue "Restarting Marzban's services"
    down_marzban
    up_marzban
    
    colorized_echo blue "Marzban updated successfully"
}


usage() {
    colorized_echo red "Usage: marzban.sh [command]"
    echo
    echo "Commands:"
    echo "  install    Install Marzban"
    echo "  up         Start services"
    echo "  down       Stop services"
    echo "  restart    Restart services"
    echo "  status     Show status"
    echo "  logs       Show logs"
    echo "  update     Update latest version"
    echo
}

case "$1" in
    install)
    shift; install_command "$@";;
    up)
    shift; up_command "$@";;
    down)
    shift; down_command "$@";;
    restart)
    shift; restart_command "$@";;
    status)
    shift; status_command "$@";;
    logs)
    shift; logs_command "$@";;
    update)
    shift; update_command "$@";;
    *)
    usage;;
esac