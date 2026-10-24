# Architecture

## iPad daemon (`native/pi5mon.c`)

Plain C, no SDK frameworks, linked only against libSystem (stub `sdk/tbd/libSystem.B.dylib.tbd`,
extracted from the device's dyld cache for Spotipad). One thread, one request at a time.

- **Lifecycle.** `/Library/LaunchDaemons/dev.pi5monitor.daemon.plist` declares a `Sockets`
  entry (`Listener`, 127.0.0.1:8899) and no `RunAtLoad`/`KeepAlive`. launchd owns the listening
  socket; the first connection starts `pi5mon`, which takes the fd with
  `launch_activate_socket("Listener")` and exits after `IDLE_SEC` (40 s) without a request.
  Run by hand it binds the port itself (`pi5mon <dir> <port> lan` binds 0.0.0.0 for tests).
- **`GET /`** serves `native/index.html`, gzipped at build time and embedded; the ETag is the
  hash of the gzip, so a reopen with an unchanged page costs a 304.
- **`GET /api/stats?h=<ip>`** runs `/usr/bin/ssh` (OpenSSH 6.7 on the iPad) with
  `ecdh-sha2-nistp256` + `ecdsa-sha2-nistp256` host key + chacha20-poly1305, `BatchMode`,
  no agent/X11/pty, own `known_hosts`. On the A5 that halves the handshake CPU compared with
  curve25519/ed25519 (0.07 s vs 0.14 s); the Pi cost is the same within noise.
- **Rates.** The daemon keeps the last fast sample in RAM. If it is younger than 35 s (polling,
  or quick manual refreshes) rates are computed against it and the request word is `x`.
  Otherwise the request is `d`: the collector takes a second fast sample 0.3 s later, so the
  first numbers after opening the app are instant values, not averages since the last visit.
  The time base is the Pi's `/proc/uptime`, so clock skew does not matter.
- **Container names.** Container ids come from cgroup scope names; names come from
  `config.v2.json` only for ids missing from `names-<ip>.txt` (one extra short SSH when a new
  container appears). Swarm task suffixes (`.1.<25 chars>`) are dropped.
- **`GET /api/disk?h=<ip>[&force=1]`** returns the storage breakdown used by the donut:
  `{at, img, ctr, vol, bc: [size, reclaimable, total, active], sc}` (bytes; Docker CLI sizes are
  decimal). It comes from collector mode `s` (`docker system df` + `du` of system caches, run
  with `nice -n 19 ionice -c 3`), which costs ~1-8 s and ~2 s of CPU on the Pi, so the result
  is cached in `<dir>/disk-<ip>.json` and only remeasured on "Measure again" (force=1) or when
  no file exists. The page combines it with the live `df` of `/` from every refresh:
  System & other = used - Docker - system cache, Free = total - used.
- **Scan.** `GET /api/scan?k=<ip,ip>`: waits up to 3 s for en0 to get its address (app opened
  right after wake-up), then non-blocking `connect()` to port 22 on all hosts of the /24 at once
  (RLIMIT_NOFILE raised to 1024), 2.5 s deadline. Known Pis (`k`, the IPs the page has opened
  before) are probed first and retried up to 3 times within 5 s, because a first miss makes iOS
  mark the host down for `net.link.ether.inet.host_down_time` (20 s). The page always lists
  known Pis under "Your Pis", so they can be opened without a scan; banner read, MAC from `sysctl(NET_RT_FLAGS, RTF_LLINFO)`,
  Raspberry Pi OUIs listed first.

JSON shape (`/api/stats`): `host, ip, ssh_ms, mode (prev|double), up, load[3], threads,
mem[total, available, cache, free], swap[total, used], temp, rp1, fan, pwm, thr, uv, freq[MHz],
df[[mount, total, used]], dt, cpu, cores[], net[[if, rx/s, tx/s, rxTotal, txTotal]],
io[[disk, read/s, write/s]], dk[[name, cpu%, anonBytes]], top[[comm, pid, cpu%, rssBytes]], nproc`.
Errors are `{"err": "..."}`.

## Pi collector (`pi/collect.sh`)

Forced command of the iPad key, `/bin/sh` (dash). It never stays running. It uses `head` with
several files so one process prints many files with `==> path <==` headers, plus its own `@name`
markers. Fast block (repeated after `@@2` in `d` mode): docker scope ids, `cpu.stat` first lines,
`/proc/stat` cpu lines, `/proc/uptime`, `/proc/net/dev`, `/proc/diskstats`, every
`/proc/<pid>/stat`. Slow block: `memory.stat` first line (anon) per container,
`vcgencmd get_throttled`, `df -P / /boot/firmware`, hostname, loadavg, meminfo, thermal zone,
hwmon (cpu, rp1_adc, pwmfan, rpi_volt), cpufreq.

Measured on the Pi 5 (Debian 13, 283 processes, 21 containers): about 10 ms CPU for the
collector, ~35-50 ms per refresh including the dropbear session and its journald lines,
~86 KB raw output (mostly `/proc/*/stat`, parsed on the iPad).

## Page (`native/index.html`)

ES5 only (Safari 9), no libraries, fonts or images. Modern dark theme: SVG ring gauges (CPU, memory, temperature 25-85 C) and an SVG donut for storage, updated through `stroke-dasharray` only. Static skeleton; updates touch only
`textContent` and style widths, table rows are reused. Sparklines are canvas ring buffers of
90 samples, cleared when leaving the device. One request in flight at most; polling (1/5/30/60 s) uses a
`setTimeout` chain timed from the start of the previous request, armed only after its reply. At
60 s the daemon has exited (40 s idle), so each sample is a fresh double sample. `visibilitychange`/`pagehide` abort the request
and set polling to Off; becoming visible again does one refresh. `localStorage` keeps only the
last Pi and the hostnames seen.
