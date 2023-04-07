#!/usr/bin/env bash

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

if [ "$(id -u)" != "0" ]; then
    colorized_echo red "This script must be run as root"
    exit 1
fi

colorized_echo blue "Installing marzban.sh"
curl -L https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh -o /usr/local/bin/marzban.sh
chmod +x /usr/local/bin/marzban.sh
colorized_echo green "marzban.sh installed successfully"