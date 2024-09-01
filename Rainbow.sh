#!/bin/bash

log() {
    local level=$1
    local message=$2
    echo "[$level] $message"
}

log "info" "Fetching and running Logo.sh..."
sleep 5
curl -s https://data.winnode.xyz/file/uploads/Logo.sh | bash
sleep 1

log "info" "Auto Install Rainbow Protocol"
echo "Auto Install Rainbow Protocol"
sleep 2

log "info" "Checking if UFW (Uncomplicated Firewall) is installed"
if ! command -v ufw &> /dev/null; then
    log "info" "UFW is not installed. Installing UFW..."
    apt-get update -y && apt-get install ufw -y
fi

log "info" "Checking if docker-compose is installed"
if ! command -v docker-compose &> /dev/null; then
    log "info" "docker-compose is not installed. Installing docker-compose...."
    apt install docker-compose
fi

log "info" "Allowing ports 22 (SSH), 5000 (Bitcoin Core), and any other necessary ports"
ufw allow 22/tcp
ufw allow 5000/tcp
ufw --force enable

log "info" "Getting VPS IP Address"
VPS_IP=$(hostname -I | awk '{print $1}')
log "info" "VPS IP Address: $VPS_IP"

log "info" "Prompting for Bitcoin Core username and password"
read -p "Enter your Bitcoin Core username: " BTC_USERNAME
read -p "Enter your Bitcoin Core password: " BTC_PASSWORD
echo

log "info" "Setting up directories and cloning repository"
mkdir -p /root/project/run_btc_testnet4/data
cd /root/project/run_btc_testnet4
git clone https://github.com/mocacinno/btc_testnet4
cd btc_testnet4
git switch bci_node

log "info" "Editing docker-compose.yml with VPS IP, username, and password"
sed -i "s/<replace_with_vps_ip>/$VPS_IP/g" docker-compose.yml
sed -i "s/<replace_with_username>/$BTC_USERNAME/g" docker-compose.yml
sed -i "s/<replace_with_password>/$BTC_PASSWORD/g" docker-compose.yml

log "info" "Starting Bitcoin Core with Docker Compose"
docker-compose up -d

log "info" "Accessing Bitcoin Core container and creating a new wallet"
docker exec -it bitcoind /bin/bash <<EOF
    bitcoin-cli -testnet4 -rpcuser=$BTC_USERNAME -rpcpassword=$BTC_PASSWORD -rpcport=5000 createwallet yourwalletname
    exit
EOF

log "info" "Downloading and setting up the indexer"
cd /root/project/run_btc_testnet4
wget https://github.com/rainbowprotocol-xyz/rbo_indexer_testnet/releases/download/v0.0.1-alpha/rbo_worker
chmod +x rbo_worker

log "info" "Starting the indexer"
./rbo_worker worker --rpc http://$VPS_IP:5000 --password $BTC_PASSWORD --username $BTC_USERNAME --start_height 42000

log "info" "Indexer logs will be shown shortly..."

log "info" "Verifying your setup"
if [ -f ./identity/principal.json ]; then
    log "info" "Verification complete! The file './identity/principal.json' exists."
    cat ./identity/principal.json
else
    log "error" "Verification failed! The file './identity/principal.json' was not found."
fi

log "info" "Setup complete! You can now view logs for Bitcoin Core and the indexer."
echo "To view Bitcoin Core logs, run:"
echo "  docker logs bitcoind"
echo "To view indexer logs, check the output in your terminal or log files generated during execution."
