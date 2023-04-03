if [ "$(id -u)" != "0" ]; then
    echo -e "\e[91mThis script must be run as root.\e[0m"
    exit 1
fi
curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh -o /usr/local/bin/marzban.sh
chmod +x /usr/local/bin/marzban.sh
