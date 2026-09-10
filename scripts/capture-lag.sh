#!/bin/sh
set -eu
umask 077

seconds=${1:-30}
case "$seconds" in
    ''|*[!0-9]*) echo "Usage: $0 [seconds: 1-300]" >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ] || [ "${#seconds}" -gt 3 ] || [ "$seconds" -lt 1 ] || [ "$seconds" -gt 300 ]; then
    echo "Usage: $0 [seconds: 1-300]" >&2
    exit 2
fi

for cmd in hyprctl jq timeout; do
    command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }
done
: "${HYPRLAND_INSTANCE_SIGNATURE:?Run from a terminal inside the affected Hyprland session}"

report_dir=$(mktemp -d "${TMPDIR:-/tmp}/hyprland-lag.XXXXXX")
report=$report_dir/capture.txt
printf 'Saving %s samples to %s\n' "$seconds" "$report"

capture() {
    printf '\n$ %s\n' "$*"
    timeout -k 1 3 "$@" 2>&1 || printf '[unavailable or timed out: %s]\n' "$*"
}

pid=$(timeout -k 1 3 hyprctl -j instances | jq -er --arg instance "$HYPRLAND_INSTANCE_SIGNATURE" \
    '.[] | select(.instance == $instance) | .pid')
case "$pid" in
    ''|*[!0-9]*) echo "Cannot identify the current compositor PID" >&2; exit 1 ;;
esac

{
    capture date -u
    capture uname -r
    capture hyprctl version
    capture hyprctl -j monitors
    for option in cursor:no_hardware_cursors cursor:use_cpu_buffer render:new_render_scheduling debug:vfr debug:damage_tracking misc:vrr; do
        capture hyprctl getoption "$option"
    done
    capture df -h / /tmp /dev/shm
    capture free -h
    capture ps -eo pid,comm,pcpu,rss,etimes --sort=-pcpu
    capture dmesg --level=err,warn

    sample=0
    while [ "$sample" -lt "$seconds" ]; do
        printf '\n=== sample %s ===\n' "$sample"
        date -u '+%Y-%m-%dT%H:%M:%SZ'
        for file in /proc/uptime /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io \
            "/proc/$pid/stat" "/proc/$pid/schedstat"; do
            printf '%s: ' "$file"
            cat "$file" 2>/dev/null || printf '[unavailable]\n'
        done
        awk '/^(MemAvailable|Dirty|Writeback|Shmem):/' /proc/meminfo
        awk '/^(Name|VmRSS|VmSwap|Threads|Cpus_allowed_list):/' "/proc/$pid/status" 2>/dev/null || :
        printf 'compositor_fds: '
        if [ -d "/proc/$pid/fd" ]; then
            find "/proc/$pid/fd" -mindepth 1 -maxdepth 1 -printf '.\n' | wc -l
        else
            printf '[compositor exited]\n'
        fi
        for file in /sys/class/drm/card[0-9]*/device/gpu_busy_percent \
            /sys/class/drm/card[0-9]*/device/mem_info_vram_used \
            /sys/class/drm/card[0-9]*/device/mem_info_vram_total; do
            [ -r "$file" ] || continue
            printf '%s: ' "$file"
            cat "$file" || :
        done
        sample=$((sample + 1))
        [ "$sample" -ge "$seconds" ] || sleep 1
    done
    capture ps -L -p "$pid" -o pid,tid,comm,cls,rtprio,ni,psr,pcpu
} >"$report" 2>&1

printf 'Saved %s\n' "$report"
