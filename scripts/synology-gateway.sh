#!/bin/bash
# ==============================================================================
# synology-gateway.sh - Persistent Boot Hook for Synology DSM (6.x & 7.x)
# Location on Synology: /usr/local/etc/rc.d/synology-gateway.sh
# ==============================================================================

LOG_FILE="/var/log/synology-gateway.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

case "$1" in
    start)
        log "=== Synology Gateway Boot Hook Starting ==="

        # 1. Ensure TUN device exists for Tailscale / VPN (DSM wipes this on restart)
        if [ ! -c /dev/net/tun ]; then
            log "Creating /dev/net/tun device..."
            mkdir -p /dev/net
            mknod /dev/net/tun c 10 200
            chmod 600 /dev/net/tun
        fi

        # 2. Ensure Tailscale daemon & subnet routes are active
        if command -v tailscale >/dev/null 2>&1; then
            log "Verifying Tailscale service..."
            tailscale status >/dev/null 2>&1 || (tailscale up --accept-routes >/dev/null 2>&1 &)
        elif [ -x /var/packages/Tailscale/target/bin/tailscale ]; then
            /var/packages/Tailscale/target/bin/tailscale status >/dev/null 2>&1 || (/var/packages/Tailscale/target/bin/tailscale up --accept-routes >/dev/null 2>&1 &)
        fi

        # 3. Trigger immediate Dynamic DNS sync
        if [ -x /usr/local/bin/cloudflare_ddns.sh ]; then
            log "Triggering Cloudflare DDNS update..."
            /usr/local/bin/cloudflare_ddns.sh >> /var/log/cloudflare_ddns.log 2>&1 &
        fi

        # 4. Restore Cron Jobs (Synology wipes /etc/crontab on DSM updates & restarts)
        CRON_MODIFIED=0
        if [ -x /usr/local/bin/cloudflare_ddns.sh ] && ! grep -q "cloudflare_ddns" /etc/crontab 2>/dev/null; then
            echo "*/10 * * * * root /usr/local/bin/cloudflare_ddns.sh >> /var/log/cloudflare_ddns.log 2>&1" >> /etc/crontab
            CRON_MODIFIED=1
        fi
        if [ -d /root/.acme.sh ] && ! grep -q "acme.sh --cron" /etc/crontab 2>/dev/null; then
            echo "0 0 * * * root /root/.acme.sh/acme.sh --cron --home /root/.acme.sh >> /var/log/acme_renew.log 2>&1" >> /etc/crontab
            CRON_MODIFIED=1
        fi
        if [ "$CRON_MODIFIED" -eq 1 ]; then
            log "Restored crontab entries; restarting crond..."
            synosystemctl restart crond 2>/dev/null || synoservice --restart crond 2>/dev/null
        fi

        # 5. Restore Nginx reverse proxy for Grokbot if DSM update wiped sites-enabled
        if [ ! -f /etc/nginx/sites-enabled/grokbot.conf ] && [ -f /usr/local/etc/grokbot-proxy.conf.bak ]; then
            log "Restoring Nginx reverse proxy configuration..."
            cp /usr/local/etc/grokbot-proxy.conf.bak /etc/nginx/sites-enabled/grokbot.conf
            synosystemctl reload nginx 2>/dev/null || synoservice --reload nginx 2>/dev/null
        fi

        # 6. Ensure user homes directory exists
        if [ -n "$SUDO_USER" ] && [ ! -d "/volume1/@fake_home_link/$SUDO_USER" ]; then
            mkdir -p "/volume1/@fake_home_link/$SUDO_USER" 2>/dev/null
            chown "$SUDO_USER:users" "/volume1/@fake_home_link/$SUDO_USER" 2>/dev/null
            chmod 700 "/volume1/@fake_home_link/$SUDO_USER" 2>/dev/null
        fi

        log "=== Synology Gateway Boot Hook Completed ==="
        ;;
    stop)
        log "Synology Gateway Service Stopping..."
        ;;
    status)
        log "Synology Gateway Service Status Check."
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac

exit 0
