#!/bin/bash
# Install or update the collector on the Pi and authorize the iPad's key, locked to it.
# Usage: IPAD_HOST=<ipad-ip> [IPAD_JUMP=...] scripts/install-pi.sh root@<pi>
# The public key is read from the iPad (/var/root/pi5monitor/id_ed25519.pub, created by
# install.sh), so no key is stored in this repo. authorized_keys is backed up once, and any
# previous pi5monitor@ipad line is replaced.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PI="${1:?usage: install-pi.sh root@pi}"
KEY=$("$ROOT/scripts/ipad-ssh.exp" 'cat /var/root/pi5monitor/id_ed25519.pub' 2>/dev/null | tr -d '\r' | grep -E '^ssh-ed25519 [A-Za-z0-9+/=]+ pi5monitor@ipad$' | tail -1)
[ -n "$KEY" ] || { echo "could not read the iPad public key (run scripts/install.sh first)"; exit 1; }
LINE="command=\"/usr/local/lib/pi5monitor/collect.sh\",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding $KEY"
ssh "$PI" 'mkdir -p /usr/local/lib/pi5monitor && cat > /usr/local/lib/pi5monitor/collect.sh && chmod 755 /usr/local/lib/pi5monitor/collect.sh' < "$ROOT/pi/collect.sh"
printf '%s\n' "$LINE" | ssh "$PI" 'f=/root/.ssh/authorized_keys; ls $f.bak-pi5monitor* >/dev/null 2>&1 || cp -p $f $f.bak-pi5monitor-$(date +%Y%m%d); { grep -v "pi5monitor@ipad" $f; cat; } > $f.new && chmod 600 $f.new && mv $f.new $f'
echo "collector + locked key installed on $PI"
