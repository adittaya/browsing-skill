#!/usr/bin/env bash
# ============================================================================
# Network Environment — detect IP type, check proxy, configure SOCKS5 proxy
# for residential IP access to bypass datacenter/VPN blocking.
# ============================================================================
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/../lib/config.sh"

usage() {
    echo "Usage: network.sh <command>"
    echo ""
    echo "Commands:"
    echo "  check               Detect IP type (residential vs datacenter)"
    echo "  proxy-status        Show current proxy configuration"
    echo "  proxy-set           Configure a SOCKS5 or HTTP proxy"
    echo "  proxy-clear         Remove proxy configuration"
    echo "  proxy-test [url]    Test connectivity through proxy"
    echo "  providers           List recommended residential proxy providers"
    exit 1
}

CMD="${1:-}"
shift || true

# ─── Helpers ─────────────────────────────────────────────────────────────────

get_public_ip() {
    # Try multiple services for reliability
    for service in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com"; do
        IP=$(curl -fsSL --max-time 5 "$service" 2>/dev/null || true)
        if [ -n "$IP" ] && [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$IP"
            return
        fi
    done
    echo ""
}

check_ip_type() {
    local ip="$1"
    if [ -z "$ip" ]; then
        ip=$(get_public_ip)
    fi
    if [ -z "$ip" ]; then
        echo "{\"ip\":\"\",\"type\":\"unknown\",\"isp\":\"\",\"org\":\"\",\"country\":\"\",\"error\":\"no_connectivity\"}"
        return
    fi

    # Use ip-api.com (free, no key needed) for ISP/org info
    local info
    info=$(curl -fsSL --max-time 5 "http://ip-api.com/json/$ip" 2>/dev/null || echo '{"status":"fail"}')

    # Determine IP type based on ISP/org
    local org isp country
    org=$(echo "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('org',''))" 2>/dev/null || echo "")
    isp=$(echo "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('isp',''))" 2>/dev/null || echo "")
    country=$(echo "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('country',''))" 2>/dev/null || echo "")

    # Detect datacenter keywords in org/isp
    local dc_keywords="digitalocean|aws|amazon|google cloud|gcp|azure|microsoft|oracle cloud|linode|vultr|hetzner|ovh|scaleway|ionos|rackspace|softlayer|ibm cloud|upcloud|baremetal|dedicated|serverstack|netcup|catalyst|hosteur|contabo|netcup|worldstream|psychz|layerstack|colocation|phoenixnap|alibaba cloud|tencent cloud|huawei cloud|vscale|timeweb|firstbyte|datapacket|packethost"
    local dc_providers="ovh|hetzner|contabo|netcup|hetzner|digitalocean|linode|vultr|scaleway"

    local ip_type="residential"

    # Check if org/isp matches datacenter patterns
    if echo "$org" | grep -qiE "$dc_keywords" || echo "$isp" | grep -qiE "$dc_keywords"; then
        ip_type="datacenter"
    fi

    # Also check via ip-api's "hosting" field which directly flags datacenters
    local hosting
    hosting=$(echo "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hosting','false'))" 2>/dev/null || echo "false")
    if [ "$hosting" = "true" ]; then
        ip_type="datacenter"
    fi

    cat <<-EOF
{
  "ip": "$ip",
  "type": "$ip_type",
  "isp": "$isp",
  "org": "$org",
  "country": "$country",
  "hosting": $hosting
}
EOF
}

# ─── Browser proxy config ────────────────────────────────────────────────────

BROWSER="${BROWSER:-surf}"

configure_browser_proxy() {
    local proxy="$1"

    case "$BROWSER" in
        surf)
            # surf uses environment variables
            export SOCKS_PROXY="$proxy"
            export HTTP_PROXY="$proxy"
            export HTTPS_PROXY="$proxy"
            export ALL_PROXY="$proxy"
            echo "export SOCKS_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            echo "export HTTP_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            echo "export HTTPS_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            echo "export ALL_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            log "surf proxy: set via environment variables"
            ;;

        firefox|qutebrowser|chromium|chromium-browser)
            # For these browsers we set system-wide env vars
            export HTTP_PROXY="$proxy"
            export HTTPS_PROXY="$proxy"
            export ALL_PROXY="$proxy"
            echo "export HTTP_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            echo "export HTTPS_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            echo "export ALL_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            log "$BROWSER proxy: set via environment variables"
            log "Note: $BROWSER may need manual proxy config in its settings"
            ;;

        links2)
            # links2 supports -proxy flag, but we'll use env vars
            export HTTP_PROXY="$proxy"
            export HTTPS_PROXY="$proxy"
            echo "export HTTP_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            echo "export HTTPS_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            log "links proxy: set via env vars (also pass -proxy $proxy)"
            ;;

        *)
            export HTTP_PROXY="$proxy"
            export HTTPS_PROXY="$proxy"
            export ALL_PROXY="$proxy"
            echo "export HTTP_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            echo "export HTTPS_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            echo "export ALL_PROXY=$proxy" >> "$DATA_DIR/proxy.env"
            log "Proxy environment variables written to $DATA_DIR/proxy.env"
            ;;
    esac
}

clear_browser_proxy() {
    rm -f "$DATA_DIR/proxy.env" 2>/dev/null || true
    unset SOCKS_PROXY HTTP_PROXY HTTPS_PROXY ALL_PROXY
    log "Proxy configuration cleared"
}

# ─── Commands ────────────────────────────────────────────────────────────────

case "$CMD" in
    check)
        echo ""
        echo "  Network Environment Check"
        echo ""

        ip=$(get_public_ip)
        if [ -z "$ip" ]; then
            echo "  ⚠ No internet connectivity detected (or DNS failing)"
            echo ""
            echo "  Possible causes:"
            echo "    - No network interface"
            echo "    - DNS not resolving"
            echo "    - Firewall blocking outbound connections"
            echo "  The skill will work but may fail on sites that require internet."
            exit 1
        fi

        echo "  Public IP:  $ip"
        echo ""

        info=$(check_ip_type "$ip")
        ip_type=$(echo "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('type','unknown'))" 2>/dev/null)
        isp=$(echo "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('isp','unknown'))" 2>/dev/null)
        org=$(echo "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('org','unknown'))" 2>/dev/null)
        country=$(echo "$info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('country','unknown'))" 2>/dev/null)

        echo "  Type:       $ip_type"
        echo "  ISP:        $isp"
        echo "  Org:        $org"
        echo "  Country:    $country"
        echo ""

        if [ "$ip_type" = "datacenter" ]; then
            echo "  ⚠ You are on a DATACENTER IP address."
            echo ""
            echo "  Many websites block datacenter IPs, VPNs, and VPS hosts."
            echo "  To get full unrestricted access to all websites, you need"
            echo "  a residential IP proxy (SOCKS5 or HTTP)."
            echo ""
            echo "  The AI agent can use a residential proxy to browse through"
            echo "  a real home IP address — this bypasses:"
            echo "    - VPN detection"
            echo "    - Datacenter blocking"
            echo "    - Captcha challenges"
            echo "    - Rate limiting"
            echo ""
            echo "  Recommended residential proxy providers:"
            echo "    Provider              | Type       | Starting Price"
            echo "   ─────────────────────────────────────────────────"
            echo "    BrightData (Luminati) | SOCKS5/HTTP | ~$0.60/GB"
            echo "    Oxylabs              | SOCKS5/HTTP | ~$0.80/GB"
            echo "    Smartproxy           | SOCKS5/HTTP | ~$1.50/GB"
            echo "    SOAX                 | SOCKS5/HTTP | ~$1.50/GB"
            echo "    IPRoyal              | SOCKS5/HTTP | ~$1.00/GB"
            echo "    Webshare             | SOCKS5/HTTP | Free tier avail."
            echo "    Proxy-Seller         | SOCKS5/HTTP | ~$0.70/IP"
            echo ""
            echo "  To configure a proxy:"
            echo "    bash network.sh proxy-set"
            echo ""
            echo "  Ask the user if they have a proxy provider, or want to"
            echo "  sign up for one of the above."
            echo ""
        else
            echo "  ✓ You are on a RESIDENTIAL IP address."
            echo "  Most websites should not block your connection."
            echo ""
        fi

        # Save to session for other scripts
        echo "$info" > "$DATA_DIR/network_info.json"
        echo "  (Network info saved to $DATA_DIR/network_info.json)"
        echo ""
        ;;

    proxy-status)
        echo ""
        echo "  Proxy Configuration"
        echo ""

        if [ -f "$DATA_DIR/proxy.env" ]; then
            echo "  Status: CONFIGURED"
            echo "  Config: $DATA_DIR/proxy.env"
            echo ""
            cat "$DATA_DIR/proxy.env" | sed 's/^/    /'
        else
            echo "  Status: NOT CONFIGURED"
        fi

        # Check system env vars
        echo ""
        echo "  Environment variables:"
        echo "    HTTP_PROXY=${HTTP_PROXY:-not set}"
        echo "    HTTPS_PROXY=${HTTPS_PROXY:-not set}"
        echo "    ALL_PROXY=${ALL_PROXY:-not set}"
        echo "    SOCKS_PROXY=${SOCKS_PROXY:-not set}"
        echo ""
        ;;

    proxy-set)
        echo ""
        echo "  Configure Proxy"
        echo ""

        # Check if proxy env already exists
        if [ -f "$DATA_DIR/proxy.env" ]; then
            log "Proxy already configured:"
            cat "$DATA_DIR/proxy.env"
            echo ""
            echo "  To reconfigure: bash network.sh proxy-clear && bash network.sh proxy-set"
            exit 0
        fi

        echo "  Enter proxy URL (e.g.):"
        echo "    SOCKS5:    socks5://user:pass@residential-proxy.com:1080"
        echo "    HTTP:      http://user:pass@proxy.example.com:8080"
        echo "    HTTPS:     https://user:pass@proxy.example.com:443"
        echo ""
        echo "  Common provider formats:"
        echo "    BrightData:  socks5://zone-residential:[TOKEN]@zproxy.lum-superproxy.io:22225"
        echo "    Oxylabs:     socks5://customer-[USER]-cc-[COUNTRY]-[TOKEN]:[PASS]@pr.oxylabs.io:7777"
        echo "    Smartproxy:  socks5://user-[USER]:[PASS]@gate.smartproxy.com:7000"
        echo "    SOAX:        socks5://[USER]:[PASS]@[SERVER].soax.com:1080"
        echo "    IPRoyal:     socks5://[TOKEN]:[TOKEN]@res.IPRoyal.io:12321"
        echo "    Webshare:    socks5://[USER]:[PASS]@p.webshare.io:1080"
        echo ""
        read -r -p "  Enter proxy URL (or press Enter to skip): " PROXY_URL </dev/tty || PROXY_URL=""

        if [ -z "$PROXY_URL" ]; then
            log "No proxy configured. Continuing without proxy."
            echo "  You can configure later: bash network.sh proxy-set"
            exit 0
        fi

        # Basic validation
        if ! echo "$PROXY_URL" | grep -qE "^(socks5|http|https)://"; then
            warn "Invalid proxy URL (must start with socks5://, http://, or https://)"
            exit 1
        fi

        configure_browser_proxy "$PROXY_URL"

        echo ""
        log "Proxy configured: $PROXY_URL"
        echo "  The browser will use this proxy for all traffic."
        echo "  To test:     bash network.sh proxy-test"
        echo "  To clear:    bash network.sh proxy-clear"
        echo ""
        ;;

    proxy-clear)
        clear_browser_proxy
        echo "  Proxy removed."
        ;;

    proxy-test)
        URL="${1:-https://httpbin.org/ip}"
        echo ""
        echo "  Testing proxy connectivity..."
        echo "  Target: $URL"
        echo ""

        # Test with proxy if configured
        if [ -f "$DATA_DIR/proxy.env" ]; then
            source "$DATA_DIR/proxy.env"
            echo "  Using configured proxy..."

            if [[ "${HTTP_PROXY:-}" =~ ^socks5 ]]; then
                # SOCKS5 test using curl with --socks5
                RESULT=$(curl -fsSL --max-time 10 --socks5-hostname "${HTTP_PROXY#socks5://}" "$URL" 2>&1 || true)
            else
                RESULT=$(curl -fsSL --max-time 10 --proxy "${HTTP_PROXY:-}" "$URL" 2>&1 || true)
            fi

            if [ -n "$RESULT" ]; then
                IP=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('origin','unknown'))" 2>/dev/null || echo "$RESULT")
                echo "  ✓ Proxy working! Exit IP: $IP"
            else
                warn "  ✗ Proxy test failed. Check your credentials and URL."
                echo "  Run: bash network.sh proxy-clear"
                echo "  Run: bash network.sh proxy-set"
                exit 1
            fi
        else
            # Direct connection test
            RESULT=$(curl -fsSL --max-time 10 "$URL" 2>&1 || true)
            if [ -n "$RESULT" ]; then
                echo "  ✓ Direct connection working"
            else
                warn "  ✗ No connectivity"
            fi
        fi
        echo ""
        ;;

    providers)
        echo ""
        echo "  Residential Proxy Providers"
        echo ""
        echo "  These providers offer residential IPs that bypass"
        echo "  datacenter/VPN blocking on websites:"
        echo ""
        echo "  ┌─────────────────────┬──────────┬──────────────────────────────┐"
        echo "  │ Provider             │ Type     │ Starting Price               │"
        echo "  ├─────────────────────┼──────────┼──────────────────────────────┤"
        echo "  │ BrightData          │ SOCKS5   │ ~\$0.60/GB (pay-as-you-go)    │"
        echo "  │ (formerly Luminati) │ HTTP      │                              │"
        echo "  ├─────────────────────┼──────────┼──────────────────────────────┤"
        echo "  │ Oxylabs             │ SOCKS5   │ ~\$0.80/GB                    │"
        echo "  │                     │ HTTP      │                              │"
        echo "  ├─────────────────────┼──────────┼──────────────────────────────┤"
        echo "  │ Smartproxy          │ SOCKS5   │ ~\$1.50/GB                    │"
        echo "  │                     │ HTTP      │                              │"
        echo "  ├─────────────────────┼──────────┼──────────────────────────────┤"
        echo "  │ SOAX                │ SOCKS5   │ ~\$1.50/GB                    │"
        echo "  │                     │ HTTP      │                              │"
        echo "  ├─────────────────────┼──────────┼──────────────────────────────┤"
        echo "  │ IPRoyal             │ SOCKS5   │ ~\$1.00/GB                    │"
        echo "  │                     │ HTTP      │                              │"
        echo "  ├─────────────────────┼──────────┼──────────────────────────────┤"
        echo "  │ Webshare            │ SOCKS5   │ Free (10 proxies)            │"
        echo "  │                     │ HTTP      │ Paid: ~\$0.50/GB             │"
        echo "  ├─────────────────────┼──────────┼──────────────────────────────┤"
        echo "  │ Proxy-Seller        │ SOCKS5   │ ~\$0.70/IP (static)          │"
        echo "  │                     │ HTTP      │                              │"
        echo "  └─────────────────────┴──────────┴──────────────────────────────┘"
        echo ""
        echo "  To configure:  bash network.sh proxy-set"
        echo "  To test:       bash network.sh proxy-test"
        echo ""
        ;;

    *)
        usage
        ;;
esac
