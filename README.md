# Marzban-scripts
Scripts for Marzban

## Installing Marzban
- **Install Marzban with SQLite**:

```bash
sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
```

- **Install Marzban with MySQL**:

  ```bash
  sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mysql
  ```

- **Install Marzban with MariaDB**:

  ```bash
  sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mariadb
  ```
  
- **Install Marzban with MariaDB and Dev branch**:

  ```bash
  sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mariadb --dev
  ```

- **Install Marzban with MariaDB and Manual version**:

  ```bash
  sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mariadb --version v0.5.2
  ```

- **Update or Change Xray-core Version**:

  ```bash
  sudo marzban core-update
  ```


## Installing Marzban-node
Install Marzban-node on your server using this command
```bash
sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban-node.sh)" @ install
```
Install Marzban-node on your server using this command with custom name:
```bash
sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban-node.sh)" @ install --name marzban-node2
```
Or you can only install this script (marzban-node command) on your server by using this command
```bash
sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban-node.sh)" @ install-script
```

Use `help` to view all commands:
```marzban-node help```

- **Update or Change Xray-core Version**:

  ```bash
  sudo marzban-node core-update
  ```
