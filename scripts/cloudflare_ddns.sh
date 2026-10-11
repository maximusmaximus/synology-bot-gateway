#!/bin/bash
# ==============================================================================
# cloudflare_ddns.sh - Automated Dynamic DNS Updater for Cloudflare
# Location on Synology: /usr/local/bin/cloudflare_ddns.sh
# ==============================================================================

# Configuration (Replace with your parameters or pass via environment)
TOKEN="${CF_TOKEN:-your_cloudflare_api_token}"
ZONE_ID="${CF_ZONE_ID:-your_zone_id}"
RECORD_ID="${CF_RECORD_ID:-your_record_id}"
RECORD_NAME="${CF_RECORD_NAME:-nas.yourdomain.com}"

LOG_FILE="/var/log/cloudflare_ddns.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 1. Fetch current public IP
CURRENT_IP=$(curl -s --max-time 10 https://api.ipify.org || curl -s --max-time 10 https://ifconfig.me)

if [ -z "$CURRENT_IP" ]; then
    log "ERROR: Could not fetch current public IP."
    exit 1
fi

# 2. Build JSON payload
PAYLOAD=$(cat <<JSON
{
  "type": "A",
  "name": "$RECORD_NAME",
  "content": "$CURRENT_IP",
  "ttl": 1,
  "proxied": false
}
JSON
)

# 3. Update Cloudflare DNS record
RESPONSE=$(curl -s --max-time 15 -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     --data "$PAYLOAD")

SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')
if [ -n "$SUCCESS" ]; then
    log "SUCCESS: DDNS updated: $RECORD_NAME -> $CURRENT_IP"
else
    log "FAILED: API response: $RESPONSE"
    exit 1
fi

exit 0
