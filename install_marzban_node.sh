#!/usr/bin/env bash

clear
echo "Installing Mazrban-node on /opt/"
sleep 2

install() {
    # Install dependencies
    sudo apt install socat -y && apt install curl socat -y && apt install git -y

    # Clone the repo on /opt and get there
    sudo git clone https://github.com/Gozargah/Marzban-node /opt/Marzban-node
    cd /opt/Marzban-node

    # Install docker
    sudo curl -fsSL https://get.docker.com | sh

    # Run Marzban-node
    sudo docker compose up -d

    # View the node cert
    sleep 3
    clear
    echo "Successfully installed Marzban-node. Copy the cert for the main panel setup:"
    sudo cat /var/lib/marzban-node/ssl_cert.pem

}

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" == "debian" ] || [ "$ID_LIKE" == "debian" ]; then
            echo "The operating system is Debian-based."
            sleep 2
            install
        else
            echo "The operating system is not Debian-based."
        fi
    else
        echo "Unable to determine the operating system."
    fi
}

check_os