# Build and deploy

## Build (`scripts/build.sh`)

- Gzips `native/index.html` and generates `native/index_gz.h` (`xxd -i`, ETag = hash).
- Compiles with `clang -target armv7s-apple-ios9.0 -isysroot MacOSX15.sdk -mcpu=cortex-a9`.
  The macOS SDK headers are fine for these POSIX/BSD calls; use MacOSX15, the beta SDK's tbd
  files break the Command Line Tools linker.
- Links with `ld -arch armv7s -ios_version_min 9.0` against `sdk/tbd/libSystem.B.dylib.tbd`,
  strips, and patches the Mach-O cpusubtype from ARM_V7S (0x0B) to ARM_V7 (0x09) so the A5
  loads it. The binary is ~70 KB.
- The binary is signed on the iPad with `ldid -S` (AppSync Unified is installed).

## Scripts

All iPad scripts use `scripts/ipad-ssh.exp` / `ipad-push.exp` (password auth, legacy ssh-rsa).
Env: `IPAD_HOST`, optional `IPAD_JUMP` (ProxyJump), `IPAD_PASS` or `~/.config/spotipad/ipad_pass`.

- `install.sh`: first install. Creates `/var/root/pi5monitor`, generates the iPad ed25519 key
  (`ssh-keygen`), installs the launchd plist and the web clip
  (`/var/mobile/Library/WebClips/<deploy/webclip-id>.webclip`), respring. Prints the public key.
- `install-pi.sh root@<pi>`: copies `pi/collect.sh` to `/usr/local/lib/pi5monitor/`, reads the
  iPad's public key from the iPad and adds it to `/root/.ssh/authorized_keys` with
  `command="...collect.sh",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding` (one-time backup
  `authorized_keys.bak-pi5monitor-<date>`, replaces older `pi5monitor@ipad` lines).
- `deploy.sh`: rebuild, push (verified by size, 3 tries), sign, `killall -9 pi5mon` (a running
  instance was seen to outlive SIGTERM); launchd starts the new binary on the
  next request.

## Testing from the Mac

Tunnel to the iPad's loopback and use curl or a headless browser:

```sh
ssh -N -L 18899:127.0.0.1:8899 [-J root@<jump-host>] <legacy opts> root@<ipad-ip>
curl 'localhost:18899/api/stats?h=<pi-ip>'
curl localhost:18899/api/scan
```

Idle check on the iPad: `launchctl list | grep pi5monitor` shows `-` as PID after 40 s.
