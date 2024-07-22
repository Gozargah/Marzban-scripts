#!/usr/bin/env bash
set -e

INSTALL_DIR="/root"
if [ -z "$APP_NAME" ]; then
    APP_NAME="marzban-node"
    APP_NAME_MAIN="marzban"
fi
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
DATA_MAIN_DIR="/var/lib/$APP_NAME_MAIN"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
LAST_XRAY_CORES=5

colorized_echo() {
    local color=$1
    local text=$2

    case $color in
        "red")
        printf "\e[91m${text}\e[0m\n";;
        "green")
        printf "\e[92m${text}\e[0m\n";;
        "yellow")
        printf "\e[93m${text}\e[0m\n";;
        "blue")
        printf "\e[94m${text}\e[0m\n";;
        "magenta")
        printf "\e[95m${text}\e[0m\n";;
        "cyan")
        printf "\e[96m${text}\e[0m\n";;
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
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update
        elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        PKG_MANAGER="yum"
        $PKG_MANAGER update -y
        $PKG_MANAGER install -y epel-release
        elif [ "$OS" == "Fedora"* ]; then
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
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        $PKG_MANAGER -y install "$PACKAGE"
        elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        $PKG_MANAGER install -y "$PACKAGE"
        elif [ "$OS" == "Fedora"* ]; then
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

install_marzban_node_script() {
    FETCH_REPO="DigneZzZ/Marzban-scripts--n"
    SCRIPT_URL="https://github.com/$FETCH_REPO/raw/node/marzban-node.sh"
    colorized_echo blue "Installing marzban script"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/marzban-node
    colorized_echo green "Marzban-NODE script installed successfully"
}

install_marzban_node() {
    # Fetch releases
    # FILES_URL_PREFIX="https://raw.githubusercontent.com/Gozargah/Marzban-node/master"

    mkdir -p "$DATA_DIR"
    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_MAIN_DIR"
 
    # File to save the certificate
    CERT_FILE="$DATA_DIR/sert.pem"

    # Remove the file if it already exists and create a new one
    > "$CERT_FILE"

    # Function to print information to the user
    print_info() {
    echo -e "\033[1;34m$1\033[0m"
    }

    # Prompt the user to input the certificate
    print_info "Please paste the content of the Client Certificate, press ENTER on a new line when finished: "

    while IFS= read -r line; do
    if [[ -z $line ]]; then
        break
    fi
    echo "$line" >> "$CERT_FILE"
    done

    print_info "Certificate saved to $CERT_FILE"


    colorized_echo blue "Generating compose file"
    # curl -sL "$FILES_URL_PREFIX/docker-compose.yml" -o "$APP_DIR/docker-compose.yml"

    # Write content to the file
    cat > "$COMPOSE_FILE" <<EOL
services:
  marzban-node:
    container_name: marzban-node
    # build: .
    image: gozargah/marzban-node:latest
    restart: always
    network_mode: host

    # env_file: .env
    environment:
      SSL_CLIENT_CERT_FILE: "$DATA_DIR/sert.pem"
      SERVICE_PROTOCOL: "rest"

    volumes:
      - $DATA_DIR:/var/lib/marzban-node
      - $DATA_MAIN_DIR:/var/lib/marzban
EOL

    colorized_echo green "File saved in $APP_DIR/docker-compose.yml"


}


uninstall_marzban_node_script() {
    if [ -f "/usr/local/bin/marzban-node" ]; then
        colorized_echo yellow "Removing marzban-node script"
        rm "/usr/local/bin/marzban-node"
    fi
}

uninstall_marzban_node() {
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "Removing directory: $APP_DIR"
        rm -r "$APP_DIR"
    fi
}

uninstall_marzban_node_docker_images() {
    images=$(docker images | grep marzban-node | awk '{print $3}')

    if [ -n "$images" ]; then
        colorized_echo yellow "Removing Docker images of Marzban-node"
        for image in $images; do
            if docker rmi "$image" >/dev/null 2>&1; then
                colorized_echo yellow "Image $image removed"
            fi
        done
    fi
}

uninstall_marzban_node_data_files() {
    if [ -d "$DATA_DIR" ]; then
        colorized_echo yellow "Removing directory: $DATA_DIR"
        rm -r "$DATA_DIR"
    fi
}

up_marzban_node() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" up -d --remove-orphans
}

down_marzban_node() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" down
}

show_marzban_node_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs
}

follow_marzban_node_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs -f
}



update_marzban_node_script() {
    #FETCH_REPO="Gozargah/Marzban-scripts"
    FETCH_REPO="DigneZzZ/Marzban-scripts--n"
    SCRIPT_URL="https://github.com/$FETCH_REPO/raw/node/marzban-node.sh"
    colorized_echo blue "Updating marzban-node script"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/marzban-node
    colorized_echo green "marzban-node script updated successfully"
}

update_marzban_node() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" pull
}

is_marzban_node_installed() {
    if [ -d $APP_DIR ]; then
        return 0
    else
        return 1
    fi
}

is_marzban_node_up() {
    if [ -z "$($COMPOSE -f $COMPOSE_FILE ps -q -a)" ]; then
        return 1
    else
        return 0
    fi
}

install_command() {
    check_running_as_root
    # Check if marzban is already installed
    if is_marzban_node_installed; then
        colorized_echo red "Marzban-node is already installed at $APP_DIR"
        read -p "Do you want to override the previous installation? (y/n) "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo red "Aborted installation"
            exit 1
        fi
    fi
    detect_os
    if ! command -v jq >/dev/null 2>&1; then
        install_package jq
    fi
    if ! command -v curl >/dev/null 2>&1; then
        install_package curl
    fi
    if ! command -v docker >/dev/null 2>&1; then
        install_docker
    fi
    detect_compose
    install_marzban_node_script
    install_marzban_node
    up_marzban_node
    follow_marzban_node_logs
}

uninstall_command() {
    check_running_as_root
    # Check if marzban is installed
    if ! is_marzban_node_installed; then
        colorized_echo red "Marzban-node not installed!"
        exit 1
    fi

    read -p "Do you really want to uninstall Marzban-node? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Aborted"
        exit 1
    fi

    detect_compose
    if is_marzban_node_up; then
        down_marzban_node
    fi
    uninstall_marzban_node_script
    uninstall_marzban_node
    uninstall_marzban_node_docker_images

    read -p "Do you want to remove Marzban-node data files too ($DATA_DIR)? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo green "Marzban-node uninstalled successfully"
    else
        uninstall_marzban_node_data_files
        colorized_echo green "Marzban-node uninstalled successfully"
    fi
}

up_command() {
    help() {
        colorized_echo red "Usage: marzban-node up [options]"
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

    # Check if marzban-node is installed
    if ! is_marzban_node_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi

    detect_compose

    if is_marzban_node_up; then
        colorized_echo red "Marzban's already up"
        exit 1
    fi

    up_marzban_node
    if [ "$no_logs" = false ]; then
        follow_marzban_node_logs
    fi
}

down_command() {

    # Check if marzban-node is installed
    if ! is_marzban_node_installed; then
        colorized_echo red "Marzban-node not installed!"
        exit 1
    fi

    detect_compose

    if ! is_marzban_node_up; then
        colorized_echo red "Marzban-node already down"
        exit 1
    fi

    down_marzban_node
}

restart_command() {
    help() {
        colorized_echo red "Usage: marzban-node restart [options]"
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

    # Check if marzban-node is installed
    if ! is_marzban_node_installed; then
        colorized_echo red "Marzban-node not installed!"
        exit 1
    fi

    detect_compose

    down_marzban_node
    up_marzban_node
    if [ "$no_logs" = false ]; then
        follow_marzban_logs
    fi
}

status_command() {

    # Check if marzban-node is installed
    if ! is_marzban_node_installed; then
        echo -n "Status: "
        colorized_echo red "Not Installed"
        exit 1
    fi

    detect_compose

    if ! is_marzban_node_up; then
        echo -n "Status: "
        colorized_echo blue "Down"
        exit 1
    fi

    echo -n "Status: "
    colorized_echo green "Up"

    json=$($COMPOSE -f $COMPOSE_FILE ps -a --format=json)
    services=$(echo "$json" | jq -r 'if type == "array" then .[] else . end | .Service')
    states=$(echo "$json" | jq -r 'if type == "array" then .[] else . end | .State')
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
        colorized_echo red "Usage: marzban-node logs [options]"
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

    # Check if marzban is installed
    if ! is_marzban_node_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi

    detect_compose

    if ! is_marzban_node_up; then
        colorized_echo red "Marzban-node is not up."
        exit 1
    fi

    if [ "$no_follow" = true ]; then
        show_marzban_node_logs
    else
        follow_marzban_node_logs
    fi
}



update_command() {
    check_running_as_root
    # Check if marzban is installed
    if ! is_marzban_node_installed; then
        colorized_echo red "Marzban-node not installed!"
        exit 1
    fi

    detect_compose

    update_marzban_node_script
    colorized_echo blue "Pulling latest version"
    update_marzban_node

    colorized_echo blue "Restarting Marzban-node services"
    down_marzban_node
    up_marzban_node

    colorized_echo blue "Marzban-node updated successfully"
}


identify_the_operating_system_and_architecture() {
    if [[ "$(uname)" == 'Linux' ]]; then
        case "$(uname -m)" in
            'i386' | 'i686')
                ARCH='32'
            ;;
            'amd64' | 'x86_64')
                ARCH='64'
            ;;
            'armv5tel')
                ARCH='arm32-v5'
            ;;
            'armv6l')
                ARCH='arm32-v6'
                grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5'
            ;;
            'armv7' | 'armv7l')
                ARCH='arm32-v7a'
                grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5'
            ;;
            'armv8' | 'aarch64')
                ARCH='arm64-v8a'
            ;;
            'mips')
                ARCH='mips32'
            ;;
            'mipsle')
                ARCH='mips32le'
            ;;
            'mips64')
                ARCH='mips64'
                lscpu | grep -q "Little Endian" && ARCH='mips64le'
            ;;
            'mips64le')
                ARCH='mips64le'
            ;;
            'ppc64')
                ARCH='ppc64'
            ;;
            'ppc64le')
                ARCH='ppc64le'
            ;;
            'riscv64')
                ARCH='riscv64'
            ;;
            's390x')
                ARCH='s390x'
            ;;
            *)
                echo "error: The architecture is not supported."
                exit 1
            ;;
        esac
    else
        echo "error: This operating system is not supported."
        exit 1
    fi
}

# Function to update the Xray core
get_xray_core() {
    identify_the_operating_system_and_architecture
    # Send a request to GitHub API to get information about the latest four releases
    latest_releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=$LAST_XRAY_CORES")

    # Extract versions from the JSON response
    versions=($(echo "$latest_releases" | grep -oP '"tag_name": "\K(.*?)(?=")'))

    # Print available versions
    echo "Available Xray-core versions:"
    for ((i=0; i<${#versions[@]}; i++)); do
        echo "$(($i + 1)): ${versions[i]}"
    done

    # Prompt the user to choose a version
    printf "Choose a version to install (1-${#versions[@]}), or press Enter to select the latest by default (${versions[0]}): "
    read choice

    # Check if a choice was made by the user
    if [ -z "$choice" ]; then
        choice="1"  # Choose the latest version by default
    fi

    # Convert the user's choice to an array index
    choice=$((choice - 1))

    # Ensure the user's choice is within available versions
    if [ "$choice" -lt 0 ] || [ "$choice" -ge "${#versions[@]}" ]; then
        echo "Invalid choice. The latest version (${versions[0]}) is selected by default."
        choice=$((${#versions[@]} - 1))  # Cho#ose the latest version by default
    fi

    # Select the version of Xray-core to install
    selected_version=${versions[choice]}
    echo "Selected version $selected_version for installation."

    # Check if the required packages are installed
    if ! dpkg -s unzip >/dev/null 2>&1; then
      echo "Installing required packages..."
      apt install -y unzip
    fi

    # Create the /var/lib/marzban/xray-core folder
    mkdir -p $DATA_MAIN_DIR/xray-core
    cd $DATA_MAIN_DIR/xray-core

    # Download the selected version of Xray-core
    xray_filename="Xray-linux-$ARCH.zip"
    xray_download_url="https://github.com/XTLS/Xray-core/releases/download/${selected_version}/${xray_filename}"

    echo "Downloading Xray-core version ${selected_version}..."
    wget "${xray_download_url}"

    # Extract the file from the archive and delete the archive
    echo "Extracting Xray-core..."
    unzip -o "${xray_filename}"
    rm "${xray_filename}"
}



# Function to update the Marzban Main core
update_core_command() {
    check_running_as_root
    get_xray_core
    # Change the Marzban core
    marzban_folder='$APP_DIR'
    xray_executable_path="XRAY_EXECUTABLE_PATH=\"/var/lib/marzban/xray-core/xray\""

    echo "Changing the Marzban core..."
    # Check if the XRAY_EXECUTABLE_PATH string already exists in the .env file
    if ! grep -q "^${xray_executable_path}" "$COMPOSE_FILE"; then
      # If the string does not exist, add it
      echo "${xray_executable_path}" >> "$COMPOSE_FILE"
    fi

    # Restart Marzban
    colorized_echo red "Restarting Marzban-node..."
    $APP_NAME restart -n
    colorized_echo blue "Installation XRAY-CORE version $selected_version completed."
}

usage() {
    colorized_echo red "Usage: marzban [command]"
    echo
    echo "Commands:"
    echo "  up              Start services"
    echo "  down            Stop services"
    echo "  restart         Restart services"
    echo "  status          Show status"
    echo "  logs            Show logs"
    echo "  install         Install Marzban-node"
    echo "  update          Update latest version"
    echo "  uninstall       Uninstall Marzban-node"
    echo "  install-script  Install Marzban-node script"
    echo "  core-update     Update/Change Xray core"
    echo
}

case "$1" in
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
    cli)
    shift; cli_command "$@";;
    install)
    shift; install_command "$@";;
    update)
    shift; update_command "$@";;
    uninstall)
    shift; uninstall_command "$@";;
    install-script)
    shift; install_marzban_node_script "$@";;
    core-update)
    shift; update_core_command "$@";;
    *)
    usage;;
esac
