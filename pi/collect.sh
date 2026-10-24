#!/bin/sh
# Pi5 Monitor collector: forced command of the iPad's SSH key. Prints raw samples and exits.
# Reads only /proc and /sys (plus `df` and `vcgencmd`); all parsing happens on the iPad.
# Request in $SSH_ORIGINAL_COMMAND:
#   d            add a second sample of the fast counters 0.3 s later (instant rates, no history)
#   n [id ...]   only print the names of these Docker containers (12+ hex chars), or of all
#   s            only print the storage breakdown (docker system df + system caches)
exec 2>/dev/null
set -- $SSH_ORIGINAL_COMMAND
if [ "$1" = s ]; then
  # Storage breakdown (heavy: dockerd walks volumes, ~2 s CPU). Only on explicit request,
  # at the lowest CPU and I/O priority.
  echo "@ddf"
  nice -n 19 ionice -c 3 docker system df --format '{{.Type}}|{{.Size}}|{{.Reclaimable}}|{{.TotalCount}}|{{.Active}}'
  echo "@sc"
  nice -n 19 ionice -c 3 du -skxc /var/cache /var/log/journal /var/lib/apt/lists /root/.cache | tail -n 1
  exit 0
fi
if [ "$1" = n ]; then
  shift
  D=/mnt/dietpi_userdata/docker-data/containers
  [ -d "$D" ] || D=/var/lib/docker/containers
  echo "@names"
  if [ $# -eq 0 ]; then exec grep -Ho -m1 ',"Name":"/[^"]*","Driver"' "$D"/*/config.v2.json; fi
  for i; do
    case "$i" in *[!0-9a-f]*) continue;; ????????????*) ;; *) continue;; esac
    set -- "$@" "$D/$i"*/config.v2.json
  done
  for f; do case "$f" in /*) grep -Ho -m1 ',"Name":"/[^"]*","Driver"' "$f";; esac; done
  exit 0
fi
MODE=$1
cd /sys/fs/cgroup/system.slice || exit 1
set -- /sys/devices/system/cpu/cpu[0-9]*
NCPU=$(($# + 1))
fast() {
  echo "@ids"; echo docker-*.scope
  echo "@dcpu"; head -qn1 docker-*.scope/cpu.stat
  echo "@stat"; head -n $NCPU /proc/stat
  head -n 100 /proc/uptime /proc/net/dev /proc/diskstats /proc/[0-9]*/stat
}
fast
echo "@dmem"; head -qn1 docker-*.scope/memory.stat
echo "@thr"; vcgencmd get_throttled
echo "@df"; df -P / /boot/firmware
head -n 60 /etc/hostname /proc/loadavg /proc/meminfo /sys/class/thermal/thermal_zone0/temp \
  /sys/class/hwmon/hwmon*/name /sys/class/hwmon/hwmon*/temp1_input /sys/class/hwmon/hwmon*/fan1_input \
  /sys/class/hwmon/hwmon*/pwm1 /sys/class/hwmon/hwmon*/in0_lcrit_alarm \
  /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq
[ "$MODE" = d ] && { sleep 0.3; echo "@@2"; fast; }
exit 0
