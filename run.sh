#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Tasker MCP add-on: reach the phone (adb wireless debugging first, tailnet second), then serve tasker-mcp over HTTP.
set -u

OPT=/data/options.json
opt() { jq -r --arg k "$1" '.[$k] // empty' "$OPT"; }

export HOME=/data/home
mkdir -p "$HOME/.android" /data/mcp-home
# a private adb server, so a host adb server on 5037 never fights with this one
export ANDROID_ADB_SERVER_PORT=15037
FWD_PORT=18220          # local end of the adb forward to the phone's Tasker server (phone port 1822)

PHONE_IP=$(opt phone_ip)
TAILNET_IP=$(opt tailnet_ip)
LISTEN=$(opt listen); LISTEN=${LISTEN:-127.0.0.1}
PORT=$(opt port); PORT=${PORT:-8765}
ACCESS_TOKEN=$(opt access_token)
TASKER_TOKEN=$(opt tasker_token)
WRITE_ALLOW=$(opt write_allow)
AUTO_PERSIST=$(opt auto_persist)
ADB_ENDPOINT=$(opt adb_endpoint)
PAIR_ENDPOINT=$(opt pair_endpoint)
PAIR_CODE=$(opt pair_code)

if [ "${#ACCESS_TOKEN}" -lt 16 ]; then
  echo "Set the access_token option (16+ characters): it is the bearer token clients must send." >&2
  exit 1
fi
if [ -z "$TASKER_TOKEN" ]; then
  echo "Set the tasker_token option (the token of the Tasker HTTP server on the phone)." >&2
  exit 1
fi

adb start-server >/dev/null 2>&1

# keeps /data/mdns_endpoint current while the phone announces Wireless debugging
rm -f /data/mdns_endpoint
python3 /discover.py "$PHONE_IP" /data/mdns_endpoint >/dev/null 2>&1 &

# one-time pairing with a Wireless debugging pairing code (Developer options > Wireless debugging > Pair device)
if [ -n "$PAIR_ENDPOINT" ] && [ -n "$PAIR_CODE" ]; then
  echo "adb pair $PAIR_ENDPOINT ..."
  adb pair "$PAIR_ENDPOINT" "$PAIR_CODE" 2>&1 | sed 's/^/  /'
  echo "Pairing attempted: clear pair_endpoint and pair_code from the options now."
fi

URL=""; SERIAL=""; ROUTE=""

setup_route() {
  URL=""; SERIAL=""; ROUTE=""
  local ep out cands=""
  # candidates, best first: the fixed option, what the mDNS watcher last saw, the last endpoint that worked
  [ -n "$ADB_ENDPOINT" ] && cands="$ADB_ENDPOINT"
  [ -s /data/mdns_endpoint ] && cands="$cands $(cat /data/mdns_endpoint)"
  [ -s /data/last_endpoint ] && cands="$cands $(cat /data/last_endpoint)"
  for ep in $cands; do
    out=$(timeout 10 adb connect "$ep" 2>&1)
    case "$out" in
      *"connected to"*|*"already connected"*)
        if adb -s "$ep" forward "tcp:$FWD_PORT" "tcp:1822" >/dev/null 2>&1; then
          echo "$ep" > /data/last_endpoint
          URL="http://127.0.0.1:$FWD_PORT"; SERIAL="$ep"; ROUTE="adb ($ep)"; return 0
        fi ;;
    esac
  done
  if [ -n "$TAILNET_IP" ]; then
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "http://$TAILNET_IP:1822/ping" 2>/dev/null || true)
    if [ -n "$code" ] && [ "$code" != 000 ]; then
      URL="http://$TAILNET_IP:1822"; ROUTE="tailnet ($TAILNET_IP, HTTP $code)"; return 0
    fi
  fi
  return 1
}

phone_ok() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$URL/ping" 2>/dev/null || true)
  [ -n "$code" ] && [ "$code" != 000 ]
}

BRIDGE_PID=""
stop_bridge() { [ -n "$BRIDGE_PID" ] && kill "$BRIDGE_PID" 2>/dev/null && wait "$BRIDGE_PID" 2>/dev/null; BRIDGE_PID=""; }
trap 'stop_bridge; adb kill-server >/dev/null 2>&1; exit 0' TERM INT

start_bridge() {
  export TASKER_URL="$URL" TASKER_TOKEN TASKER_MCP_HOME=/data/mcp-home TASKER_WRITE_ALLOW="$WRITE_ALLOW"
  export TASKER_AUTO_PERSIST="$AUTO_PERSIST"
  [ -n "$SERIAL" ] && export TASKER_ADB=/usr/local/bin/adb TASKER_ADB_SERIAL="$SERIAL"
  export TASKER_MCP_DIR="$(npm root -g)/@pmaxhogan/tasker-mcp"
  export BRIDGE_LISTEN="$LISTEN" BRIDGE_PORT="$PORT" BRIDGE_ACCESS_TOKEN="$ACCESS_TOKEN"
  node /bridge.mjs &
  BRIDGE_PID=$!
}

FAILS=0
while true; do
  if [ -z "$BRIDGE_PID" ] || ! kill -0 "$BRIDGE_PID" 2>/dev/null; then
    stop_bridge
    if setup_route; then
      echo "phone route: $ROUTE"
      start_bridge
      FAILS=0
    else
      echo "phone not reachable (no wireless debugging endpoint, no tailnet answer); retrying in 30 s" >&2
      sleep 30
      continue
    fi
  fi
  sleep 30
  if phone_ok; then FAILS=0; else FAILS=$((FAILS + 1)); fi
  if [ "$FAILS" -ge 3 ]; then
    echo "phone route lost ($ROUTE): reconnecting" >&2
    stop_bridge
    FAILS=0
  fi
done
