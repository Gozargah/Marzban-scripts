#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt"
if [ -z "$APP_NAME" ]; then
    APP_NAME="marzban"
fi
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
ENV_FILE="$APP_DIR/.env"
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

install_marzban_script() {
    FETCH_REPO="Gozargah/Marzban-scripts"
    SCRIPT_URL="https://github.com/$FETCH_REPO/raw/master/marzban.sh"
    colorized_echo blue "Installing marzban script"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/marzban
    colorized_echo green "marzban script installed successfully"
}

install_marzban() {
    local marzban_version=$1
    # Fetch releases
    FILES_URL_PREFIX="https://raw.githubusercontent.com/Gozargah/Marzban/master"

    mkdir -p "$DATA_DIR"
    mkdir -p "$APP_DIR"

    colorized_echo blue "Fetching compose file"
    curl -sL "$FILES_URL_PREFIX/docker-compose.yml" -o "$APP_DIR/docker-compose.yml"
    docker_file_path="$APP_DIR/docker-compose.yml"
    # install requested version
    if [ "$marzban_version" == "latest" ]; then
        sed -i "s|image: gozargah/marzban:.*|image: gozargah/marzban:latest|g" "$docker_file_path"
    else
        sed -i "s|image: gozargah/marzban:.*|image: gozargah/marzban:${marzban_version}|g" "$docker_file_path"
    fi
    echo "Installing $marzban_version version"
    colorized_echo green "File saved in $APP_DIR/docker-compose.yml"

    colorized_echo blue "Fetching .env file"
    curl -sL "$FILES_URL_PREFIX/.env.example" -o "$APP_DIR/.env"
    sed -i 's/^# \(XRAY_JSON = .*\)$/\1/' "$APP_DIR/.env"
    sed -i 's/^# \(SQLALCHEMY_DATABASE_URL = .*\)$/\1/' "$APP_DIR/.env"
    sed -i 's~\(XRAY_JSON = \).*~\1"/var/lib/marzban/xray_config.json"~' "$APP_DIR/.env"
    sed -i 's~\(SQLALCHEMY_DATABASE_URL = \).*~\1"sqlite:////var/lib/marzban/db.sqlite3"~' "$APP_DIR/.env"
    colorized_echo green "File saved in $APP_DIR/.env"

    colorized_echo blue "Fetching xray config file"
    curl -sL "$FILES_URL_PREFIX/xray_config.json" -o "$DATA_DIR/xray_config.json"
    colorized_echo green "File saved in $DATA_DIR/xray_config.json"

    colorized_echo green "Marzban's files downloaded successfully"
}


uninstall_marzban_script() {
    if [ -f "/usr/local/bin/marzban" ]; then
        colorized_echo yellow "Removing marzban script"
        rm "/usr/local/bin/marzban"
    fi
}

uninstall_marzban() {
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "Removing directory: $APP_DIR"
        rm -r "$APP_DIR"
    fi
}

uninstall_marzban_docker_images() {
    images=$(docker images | grep marzban | awk '{print $3}')

    if [ -n "$images" ]; then
        colorized_echo yellow "Removing Docker images of Marzban"
        for image in $images; do
            if docker rmi "$image" >/dev/null 2>&1; then
                colorized_echo yellow "Image $image removed"
            fi
        done
    fi
}

uninstall_marzban_data_files() {
    if [ -d "$DATA_DIR" ]; then
        colorized_echo yellow "Removing directory: $DATA_DIR"
        rm -r "$DATA_DIR"
    fi
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

marzban_cli() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" exec -e CLI_PROG_NAME="marzban cli" marzban marzban-cli "$@"
}


update_marzban_script() {
    FETCH_REPO="Gozargah/Marzban-scripts"
    SCRIPT_URL="https://github.com/$FETCH_REPO/raw/master/marzban.sh"
    colorized_echo blue "Updating marzban script"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/marzban
    colorized_echo green "marzban script updated successfully"
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
    install_marzban_script
    # Function to check if a version exists in the GitHub releases
    check_version_exists() {
        local version=$1
        repo_url="https://api.github.com/repos/Gozargah/Marzban/releases"
        if [ "$version" == "latest" ]; then
            return 0
        fi

        # Fetch the release data from GitHub API
        response=$(curl -s "$repo_url")

        # Check if the response contains the version tag
        if echo "$response" | jq -e ".[] | select(.tag_name == \"${version}\")" > /dev/null; then
            return 0
        else
            return 1
        fi
    }
    # Check if the version is valid and exists
    if [[ "$1" == "latest" || "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if check_version_exists "$1"; then
                install_marzban "$1"
            echo "Installing $1 version"
        else
            echo "Version $1 does not exist. Please enter a valid version (e.g. v0.5.2)"
            exit 1
        fi
    else
        echo "Invalid version format. Please enter a valid version (e.g. v0.5.2)"
        exit 1
    fi
    up_marzban
    follow_marzban_logs
}

uninstall_command() {
    check_running_as_root
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi

    read -p "Do you really want to uninstall Marzban? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Aborted"
        exit 1
    fi

    detect_compose
    if is_marzban_up; then
        down_marzban
    fi
    uninstall_marzban_script
    uninstall_marzban
    uninstall_marzban_docker_images

    read -p "Do you want to remove Marzban's data files too ($DATA_DIR)? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo green "Marzban uninstalled successfully"
    else
        uninstall_marzban_data_files
        colorized_echo green "Marzban uninstalled successfully"
    fi
}

up_command() {
    help() {
        colorized_echo red "Usage: marzban up [options]"
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

    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi

    detect_compose

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

    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi

    detect_compose

    if ! is_marzban_up; then
        colorized_echo red "Marzban's already down"
        exit 1
    fi

    down_marzban
}

restart_command() {
    help() {
        colorized_echo red "Usage: marzban restart [options]"
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

    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi

    detect_compose

    down_marzban
    up_marzban
    if [ "$no_logs" = false ]; then
        follow_marzban_logs
    fi
}

status_command() {

    # Check if marzban is installed
    if ! is_marzban_installed; then
        echo -n "Status: "
        colorized_echo red "Not Installed"
        exit 1
    fi

    detect_compose

    if ! is_marzban_up; then
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
        colorized_echo red "Usage: marzban logs [options]"
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
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi

    detect_compose

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

cli_command() {
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi

    detect_compose

    if ! is_marzban_up; then
        colorized_echo red "Marzban is not up."
        exit 1
    fi

    marzban_cli "$@"
}

update_command() {
    check_running_as_root
    # Check if marzban is installed
    if ! is_marzban_installed; then
        colorized_echo red "Marzban's not installed!"
        exit 1
    fi

    detect_compose

    update_marzban_script
    colorized_echo blue "Pulling latest version"
    update_marzban

    colorized_echo blue "Restarting Marzban's services"
    down_marzban
    up_marzban

    colorized_echo blue "Marzban updated successfully"
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
    mkdir -p $DATA_DIR/xray-core
    cd $DATA_DIR/xray-core

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
    if ! grep -q "^${xray_executable_path}" "$ENV_FILE"; then
      # If the string does not exist, add it
      echo "${xray_executable_path}" >> "$ENV_FILE"
    fi

    # Restart Marzban
    colorized_echo red "Restarting Marzban..."
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
    echo "  cli             Marzban CLI"
    echo "  install         Install Marzban"
    echo "  update          Update latest version"
    echo "  uninstall       Uninstall Marzban"
    echo "  install-script  Install Marzban script"
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
    shift; install_command "${1:-latest}";;
    update)
    shift; update_command "$@";;
    uninstall)
    shift; uninstall_command "$@";;
    install-script)
    shift; install_marzban_script "$@";;
    core-update)
    shift; update_core_command "$@";;
    *)
    usage;;
esac
