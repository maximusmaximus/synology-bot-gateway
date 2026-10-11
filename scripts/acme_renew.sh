#!/bin/bash
# ==============================================================================
# acme_renew.sh - Let's Encrypt Certificate Renewal & Synology DSM Deployment
# ==============================================================================

DOMAIN="${1:-emergencyexit.vmu.cash}"
ACME_HOME="${ACME_HOME:-/root/.acme.sh}"
LOG_FILE="/var/log/acme_renew.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

if [ ! -f "$ACME_HOME/acme.sh" ]; then
    log "ERROR: acme.sh not found at $ACME_HOME/acme.sh"
    exit 1
fi

log "Checking certificate renewal for $DOMAIN..."
"$ACME_HOME/acme.sh" --cron --home "$ACME_HOME" >> "$LOG_FILE" 2>&1

# If Synology deployment hook is configured
if [ -n "$SYNO_Username" ] && [ -n "$SYNO_Password" ]; then
    log "Deploying updated certificate to Synology DSM..."
    "$ACME_HOME/acme.sh" --deploy --deploy-hook synology_dsm -d "$DOMAIN" >> "$LOG_FILE" 2>&1
fi

log "Renewal cycle finished."
exit 0
