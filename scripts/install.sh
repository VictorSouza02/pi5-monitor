#!/bin/bash
# First-time install on the iPad: data dir + SSH key, launchd socket job, home-screen web clip.
# Then run scripts/install-pi.sh root@<pi> to authorize the iPad key on the Pi.
# Env: IPAD_HOST, optional IPAD_JUMP, IPAD_PASS (or ~/.config/spotipad/ipad_pass).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/scripts"
W="/var/mobile/Library/WebClips/$(cat "$ROOT/deploy/webclip-id").webclip"
P=/Library/LaunchDaemons/dev.pi5monitor.daemon.plist
"$S/build.sh"
"$S/ipad-ssh.exp" "mkdir -p /var/root/pi5monitor '$W'"
"$S/ipad-push.exp" "$ROOT/native/pi5mon" /var/root/pi5monitor/pi5mon
"$S/ipad-push.exp" "$ROOT/deploy/dev.pi5monitor.daemon.plist" $P
"$S/ipad-push.exp" "$ROOT/deploy/webclip-Info.plist" "$W/Info.plist"
"$S/ipad-push.exp" "$ROOT/deploy/icon.png" "$W/icon.png"
"$S/ipad-ssh.exp" "cd /var/root/pi5monitor && { [ -f id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -C pi5monitor@ipad -f id_ed25519; } && ldid -S pi5mon && chown root:wheel $P && chmod 644 $P && chown -R mobile:mobile '$W' && launchctl unload $P 2>/dev/null; launchctl load $P && cat id_ed25519.pub && killall -9 SpringBoard"
