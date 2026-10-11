# Synology Bot Gateway & Persistence Toolkit 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Synology DSM](https://img.shields.io/badge/Platform-Synology%20DSM%207.x%20%7C%206.x-blue.svg)](https://www.synology.com/dsm)
[![Security: Let's Encrypt](https://img.shields.io/badge/Security-Let's%20Encrypt%20SSL-green.svg)](https://letsencrypt.org/)
[![DNS: Cloudflare](https://img.shields.io/badge/DNS-Cloudflare%20API-orange.svg)](https://www.cloudflare.com/)

A production-ready framework to connect **AI bots (Grok, OpenAI GPT Actions, Claude, Slack/Discord webhooks)** and remote services to your Synology NAS with **100% reboot and firmware-update persistence**.

---

## 📌 The Problems This Solves

When connecting automated bots or remote services to a Synology NAS, several major roadblocks occur:

1. **The Non-Standard Port Trap (Port 5001 Blocked)**:
   - Cloud AI platforms (like xAI's Grok, OpenAI Actions, AWS Lambda, webhooks) **strictly block outbound connections to non-standard ports** like `:5001`. They only permit standard HTTPS (`:443`).
   - If an AI bot tries to call `https://your-nas.domain.com:5001`, the bot's cloud sandbox drops the connection instantly.
2. **Settings Wiped on Reboot / DSM Update**:
   - Synology DSM resets `/etc/crontab` and clears custom system configuration upon reboot and minor system updates.
   - Custom background daemons, DDNS updaters, and cert renewal scripts silently disappear.
3. **Auto-Block Banning Bots**:
   - Synology DSM's Auto-Block feature permanently bans IP addresses that make 5 failed attempts in 5 minutes. Rapid health checks or unauthenticated bot calls get blacklisted.
4. **Tailscale TUN Device Resets**:
   - Tailscale on DSM 7 requires `/dev/net/tun`, which is wiped from memory on system restart.

---

## 🏗️ Architecture

```
[ External Internet / Grokbot / AI Agents ]
                     │
                     ▼ (Standard HTTPS Port 443)
          [ Cloudflare DNS (vmu.cash) ]
                     │
                     ▼
          [ Home Router (Port Forward 443) ]
                     │
                     ▼
        [ Synology NAS (10.1.10.62) ]
  ┌──────────────────────────────────────────────────────────┐
  │  /usr/local/etc/rc.d/synology-gateway.sh (Persistent)    │
  │  ├── Recreates /dev/net/tun for Tailscale                │
  │  ├── Verifies Tailscale Mesh Connection                  │
  │  ├── Restores Crontabs (Cloudflare DDNS + acme.sh SSL)   │
  │  └── Syncs Public WAN IP to Cloudflare API               │
  │                                                          │
  │  Nginx Reverse Proxy (Port 443 -> DSM Port 5001 / Apps)  │
  │  └── Includes CORS headers & WebSocket support           │
  │                                                          │
  │  Auto-Block Protection & Allowlist Configuration         │
  └──────────────────────────────────────────────────────────┘
```

---

## 🚀 Quickstart Installation (via SSH)

### 1. Connect to your Synology NAS
```bash
ssh <your-username>@<your-nas-local-ip>
sudo -i
```

### 2. Clone and Run the Installer
```bash
git clone https://github.com/maximusmaximus/synology-bot-gateway.git
cd synology-bot-gateway
bash install.sh
```

*(Alternatively, copy `scripts/synology-gateway.sh` directly to `/usr/local/etc/rc.d/synology-gateway.sh` and make it executable: `chmod 755 /usr/local/etc/rc.d/synology-gateway.sh`)*

---

## ⚙️ Component Breakdown

### 1. Persistent Boot Hook (`/usr/local/etc/rc.d/synology-gateway.sh`)
Synology DSM provides `/usr/local/etc/rc.d/` as the official directory for persistent user init scripts. Any executable script ending in `.sh` is run with argument `start` during boot and survives DSM updates.

* **Recreates `/dev/net/tun`**: Restores the TUN interface needed for WireGuard/Tailscale.
* **Starts Tailscale**: Ensures continuous mesh VPN connectivity.
* **Auto-Repairs Crontab**: Automatically detects if `/etc/crontab` was reset by DSM and re-inserts the DDNS updater and SSL renewal jobs.

### 2. Automated Cloudflare Dynamic DNS (`scripts/cloudflare_ddns.sh`)
* Syncs your dynamic public IP to your Cloudflare DNS zone every 10 minutes.
* Uses modern Cloudflare API Bearer Tokens (`Zone:DNS:Edit`).
* Runs silently in the background with logs directed to `/var/log/cloudflare_ddns.log`.

### 3. Automated SSL Certificate (via `acme.sh` & Cloudflare DNS-01)
* Automatically requests and renews Let's Encrypt wildcard / domain certificates without opening port 80.
* Deploys directly into DSM's certificate store using the `synology_dsm` deploy hook.

### 4. Standard Port 443 Reverse Proxy (`nginx/synology-bot-reverse-proxy.conf`)
* Routes traffic from `https://your-domain.com` (Port 443) to DSM (Port 5001) or containerized bot endpoints.
* Adds CORS headers (`Access-Control-Allow-Origin: *`) to enable browser-based AI tool execution.
* Enables WebSocket upgrade headers for streaming bot responses.

---

## 🤖 Configuring Grokbot / AI Agent Access

### Step 1: Forward Port 443 in Your Router
In your router's port forwarding settings:
* **Service:** `HTTPS_Bot`
* **External Port:** `443`
* **Internal IP:** Your Synology local IP (e.g., `10.1.10.62`)
* **Internal Port:** `5001` *(or `443` if using Nginx reverse proxy)*
* **Protocol:** `TCP`

### Step 2: Prevent Auto-Block Lockouts
In DSM:
1. Open **Control Panel** $\rightarrow$ **Security** $\rightarrow$ **Account**.
2. Under **Auto Block**:
   - Set **Login attempts:** `10` or higher within `10` minutes.
   - Check **Enable block expiration** (unblock after `1` day).
3. Under **Allow List**, add trusted bot IP subnets if known.

### Step 3: Test Bot Connection
In your bot configuration, set your endpoint to:
```text
https://emergencyexit.vmu.cash/
```
*(No port `:5001` needed!)*

---

## 🔍 Verification & Logs

Check status of the persistent boot gateway:
```bash
cat /var/log/synology-gateway.log
```

Check Dynamic DNS updates:
```bash
cat /var/log/cloudflare_ddns.log
```

Check SSL certificate renewal:
```bash
cat /var/log/acme_renew.log
```

---

## 📄 License
This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.
