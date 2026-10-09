#!/usr/bin/env bash
# Connects the CI job to a VPN (Sophos SSL VPN / any OpenVPN profile) so the
# tests can reach environments that are only available through it.
# Does nothing when VPN_CONFIG is empty, so projects without a VPN are unaffected.
#
#   VPN_CONFIG    base64 of the complete .ovpn file (CA, client cert/key and
#                 tls-auth / tls-crypt key inline):  base64 -i client.ovpn
#   VPN_USERNAME  only if the profile contains `auth-user-pass`
#   VPN_PASSWORD
#
# The job container needs NET_ADMIN and /dev/net/tun (see the CI files).
#
# Usage: scripts/vpn.sh up | down
set -euo pipefail

DIR="${RUNNER_TEMP:-/tmp}/vpn"
PID="$DIR/openvpn.pid"
LOG="$DIR/openvpn.log"

up() {
  if [ -z "${VPN_CONFIG:-}" ]; then
    echo "VPN_CONFIG not set, skipping VPN"
    return
  fi
  if [ ! -c /dev/net/tun ]; then
    echo "VPN: /dev/net/tun is missing. Run the job container with --cap-add=NET_ADMIN --device /dev/net/tun" >&2
    exit 1
  fi

  command -v openvpn >/dev/null || {
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends openvpn >/dev/null
  }

  umask 077
  mkdir -p "$DIR"
  printf '%s' "$VPN_CONFIG" | base64 -d >"$DIR/client.ovpn"

  local args=(--config "$DIR/client.ovpn")
  if [ -n "${VPN_USERNAME:-}" ]; then
    printf '%s\n%s\n' "$VPN_USERNAME" "${VPN_PASSWORD:-}" >"$DIR/auth.txt"
    args+=(--auth-user-pass "$DIR/auth.txt")
  elif grep -q '^auth-user-pass' "$DIR/client.ovpn"; then
    echo "VPN: the profile needs a username/password, set VPN_USERNAME and VPN_PASSWORD" >&2
    exit 1
  fi

  # OpenVPN does not apply pushed DNS servers on Linux by itself
  cat >"$DIR/dns.sh" <<'EOF'
#!/bin/sh
opts=$(env | grep '^foreign_option_' | cut -d= -f2-)
dns=$(echo "$opts" | sed -n 's/^dhcp-option DNS /nameserver /p')
domain=$(echo "$opts" | sed -n 's/^dhcp-option DOMAIN /search /p')
[ -n "$dns" ] || exit 0
cp /etc/resolv.conf /etc/resolv.conf.pre-vpn
{ echo "$domain"; echo "$dns"; cat /etc/resolv.conf.pre-vpn; } >/etc/resolv.conf
EOF
  chmod 700 "$DIR/dns.sh"

  openvpn "${args[@]}" --daemon --log "$LOG" --writepid "$PID" \
    --script-security 2 --up "$DIR/dns.sh"

  for _ in $(seq 1 60); do
    if grep -q 'Initialization Sequence Completed' "$LOG" 2>/dev/null; then
      echo "VPN connected"
      return
    fi
    if grep -qE 'AUTH_FAILED|Exiting due to fatal error' "$LOG" 2>/dev/null; then break; fi
    if [ -f "$PID" ] && ! kill -0 "$(cat "$PID")" 2>/dev/null; then break; fi
    sleep 1
  done

  echo "VPN connection failed:" >&2
  tail -n 30 "$LOG" >&2 || true
  exit 1
}

down() {
  [ -d "$DIR" ] || return 0
  if [ -f "$PID" ]; then kill "$(cat "$PID")" 2>/dev/null || true; fi
  if [ -f /etc/resolv.conf.pre-vpn ]; then cat /etc/resolv.conf.pre-vpn >/etc/resolv.conf; fi
  rm -rf "$DIR"
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  *) echo "usage: $0 up|down" >&2; exit 2 ;;
esac
