#!/bin/bash
# ==============================================================================
# install.sh - Automated installer for Synology Bot Gateway & Persistent Services
# Run via SSH as root on Synology DSM: sudo bash install.sh
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}      Synology Bot Gateway & Persistence Setup        ${NC}"
echo -e "${BLUE}======================================================${NC}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo -i).${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install Persistent Boot Hook
echo -e "\n${GREEN}[1/4] Installing /usr/local/etc/rc.d/synology-gateway.sh...${NC}"
mkdir -p /usr/local/etc/rc.d
cp "$SCRIPT_DIR/scripts/synology-gateway.sh" /usr/local/etc/rc.d/synology-gateway.sh
chmod 755 /usr/local/etc/rc.d/synology-gateway.sh
echo "✓ Boot hook installed."

# 2. Deploy Cloudflare DDNS script
echo -e "\n${GREEN}[2/4] Setting up Cloudflare Dynamic DNS updater...${NC}"
if [ -f "$SCRIPT_DIR/scripts/cloudflare_ddns.sh" ]; then
    cp "$SCRIPT_DIR/scripts/cloudflare_ddns.sh" /usr/local/bin/cloudflare_ddns.sh
    chmod 755 /usr/local/bin/cloudflare_ddns.sh
    echo "✓ DDNS script placed at /usr/local/bin/cloudflare_ddns.sh."
fi

# 3. Configure Crontab & execute boot hook
echo -e "\n${GREEN}[3/4] Initializing services and crontab persistence...${NC}"
/usr/local/etc/rc.d/synology-gateway.sh start
echo "✓ Services initialized."

# 4. Verification
echo -e "\n${GREEN}[4/4] Verifying setup...${NC}"
if [ -f "/var/log/synology-gateway.log" ]; then
    tail -n 6 /var/log/synology-gateway.log
fi

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}  Installation Complete! Settings will survive reboot.${NC}"
echo -e "${GREEN}======================================================${NC}"
