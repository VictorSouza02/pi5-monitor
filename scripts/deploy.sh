#!/bin/bash
# Rebuild and replace the daemon on the iPad. launchd keeps the socket; the next request starts
# the new binary. Env as in install.sh. Fails loudly if the push or the swap did not happen.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/scripts"
"$S/build.sh"
SIZE=$(stat -f %z "$ROOT/native/pi5mon")
for try in 1 2 3; do
  "$S/ipad-push.exp" "$ROOT/native/pi5mon" /var/root/pi5monitor/pi5mon.new >/dev/null 2>&1 || true
  if "$S/ipad-ssh.exp" "[ \$(stat -f %z /var/root/pi5monitor/pi5mon.new 2>/dev/null || echo 0) = $SIZE ] && echo PUSH_OK" 2>/dev/null | grep -q PUSH_OK; then break; fi
  [ $try = 3 ] && { echo "push to iPad failed"; exit 1; }
  sleep 2
done
"$S/ipad-ssh.exp" 'cd /var/root/pi5monitor && ldid -S pi5mon.new && mv pi5mon.new pi5mon && { killall -9 pi5mon 2>/dev/null; true; } && echo DEPLOY_OK' 2>/dev/null | grep -q DEPLOY_OK \
  || { echo "swap on iPad failed"; exit 1; }
echo "deployed $(grep INDEX_ETAG "$ROOT/native/index_gz.h" | cut -d'"' -f2)"
