#!/usr/bin/env bash
# =====================================================
# Demo telemetry poster (Linux)
#
# Posts machine details to the WebUI, which then forwards
# them to the database. Override the target with WEBUI_URL:
#
#   WEBUI_URL="https://your-site.com" ./post-demo.sh
# =====================================================

WEBUI_URL="${WEBUI_URL:-https://liveip.ratul.fun}"
ENDPOINT="${WEBUI_URL%/}/api/telemetry"

MACHINE_ID="${MACHINE_ID:-linux-demo-$(hostname)}"
HOSTNAME_VAL="$(hostname)"
IP="$(curl -fsS --max-time 5 https://api.ipify.org || echo Unknown)"
USER_VAL="${USER:-$(whoami)}"
OS_VAL="$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -sr)"
CPU="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | sed 's/.*: //' | xargs || echo Unknown)"
RAM_KB="$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')"
RAM="$([ -n "$RAM_KB" ] && echo "$(( RAM_KB / 1024 / 1024 )) GB" || echo Unknown)"
DISK="$(df -BG --output=size / 2>/dev/null | tail -1 | tr -dc '0-9')"
DISK="${DISK:+${DISK} GB}"; DISK="${DISK:-Unknown}"

PAYLOAD=$(cat <<EOF
{
  "machineId": "${MACHINE_ID}",
  "hostname":  "${HOSTNAME_VAL}",
  "ip":        "${IP}",
  "user":      "${USER_VAL}",
  "os":        "${OS_VAL}",
  "cpu":       "${CPU}",
  "ram":       "${RAM}",
  "disk":      "${DISK}"
}
EOF
)

echo "POST $ENDPOINT"
echo "$PAYLOAD"
echo
curl -sS -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
echo
