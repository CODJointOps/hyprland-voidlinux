# Desktop freezes and cursor lag

## Capture the affected session

Run this once when the desktop is healthy, then again while the problem is
happening, before moving the pointer onto the frozen monitor or restarting:

```sh
./scripts/capture-lag.sh 30
```

The script writes a private `capture.txt` under `/tmp/hyprland-lag.*`. It needs
`hyprctl`, `jq`, and coreutils. Its argument selects 1-300 samples, roughly one
second apart, after the initial snapshot. It does not change settings, start
animations, move the pointer, restart services, or install packages. The initial
snapshot queries the compositor; a completely passive trace would need separate
instrumentation. Compositor queries and initial snapshot commands have timeouts.
Kernel logs are collected
only if the current user can read them; the script never invokes sudo.

The report includes versions, monitor state, relevant options, filesystem usage,
memory and CPU/I/O pressure, compositor CPU counters, scheduler wait time, RSS,
file-descriptor count, and available AMD GPU load/VRAM counters. It omits window
titles, process arguments, environment variables, and config contents. Review
machine/device identifiers, process names, and kernel messages before sharing.
Keep reports outside Git. Copy them out of `/tmp` before rebooting if needed.

Record which monitor froze, browser name, whether audio continued, and the time
the pointer restored updates. Compare compositor CPU and scheduler counters
between samples. `ps %CPU` is a lifetime average, not instantaneous CPU load.
Rising RSS or descriptor counts across captures are evidence to investigate,
not proof of a leak. GPU saturation and I/O stalls can occur with spare CPU.

## Findings from the affected Void desktop, 2026-09-10

- Hyprland 0.56.2_5, Aquamarine 0.14.0_2, Mesa 26.1.8, kernel 7.0.13-lqx2_1.
  The repository's Aquamarine template is newer than the installed library.
- AMD RX 6600 drives 1080p/100 Hz and 1440p/165 Hz outputs. NVIDIA is bound to
  `vfio-pci`; NVIDIA compositor workarounds do not match this setup.
- Both outputs reported software cursors. The Lua config explicitly forced
  `cursor.no_hardware_cursors = true`. Setting it to `false` made both outputs
  report `hardwareCursorsInUse: true`, with no config errors. That setting was
  persisted in the affected desktop's `~/.config/hypr/lua/settings.lua`.
- `render.new_render_scheduling` and `debug.vfr` were enabled. Effective VRR
  was disabled on both outputs, despite different values in earlier config
  fragments. Check `hyprctl monitors`, not just one source file.
- At about 19.5 hours uptime, brief samples showed no memory pressure and
  substantial idle CPU. GPU load reached 77%. Root filesystem usage rounded
  to 100%, with 27 GiB available out of 3.7 TiB. These are observations from
  this session, not established causes of the reported degradation.
- A 20-second `weston-simple-shm` run on each monitor, with `WAYLAND_DEBUG=1`,
  produced 1,825 and 2,525 frame intervals. Maximum completed frame-callback
  gaps were 38 ms and 43 ms. The reported persistent freeze did not reproduce.
  Frame callbacks do not measure physical scanout or input-to-photon latency.
- A trial with the new scheduler disabled was inconclusive because test windows
  became obscured during use. The original scheduler setting was restored.

The cursor change is a tested configuration mitigation, not a confirmed fix for
the day-long freeze or input lag. No compositor/backend source patch is justified
by these captures yet. The remaining test is a capture during the real freeze
and comparison after sustained use with hardware cursors enabled.

## Relevant upstream reports

[Hyprland #10979](https://github.com/hyprwm/Hyprland/issues/10979) tracks lags and
stutters with `render:new_render_scheduling`, including multi-monitor reports.
Disabling it helped some reporters. This is a candidate for a controlled test,
not proof that the current session has that bug.

[Hyprland #8802](https://github.com/hyprwm/Hyprland/issues/8802) describes updates
improving when the mouse moves. That reporter resolved it with a monitor VRR
setting. Similar symptoms can have different causes.

[Hyprland #16105](https://github.com/hyprwm/Hyprland/issues/16105) describes stalled
frame callbacks on 0.56.2 that resume with pointer movement. Its trigger is a
locked session resuming from suspend, which has not been established here.

## Controlled tests on Hyprland 0.56.2 with Lua config

Capture first. Change one option, repeat the same workload, then restore it
before testing another. Opening an animated probe on the frozen output can
itself restart rendering and hide the original failure.

To allow hardware cursors at runtime:

```sh
hyprctl eval 'hl.config({cursor={no_hardware_cursors=false}})'
hyprctl monitors
```

Check `hardwareCursorsInUse`. To undo this desktop's cursor change, set the
`cursor` entry in `~/.config/hypr/lua/settings.lua` back to
`no_hardware_cursors = true`, then run:

```sh
hyprctl eval 'hl.config({cursor={no_hardware_cursors=true}})'
```

To test the scheduler independently:

```sh
hyprctl eval 'hl.config({render={new_render_scheduling=false}})'
# Restore the original setting after the comparison:
hyprctl eval 'hl.config({render={new_render_scheduling=true}})'
```

Only if callbacks stall while the pointer is elsewhere, test continuous
rendering separately:

```sh
hyprctl eval 'hl.config({debug={vfr=false}})'
# Restore after the comparison; continuous rendering increases idle GPU work:
hyprctl eval 'hl.config({debug={vfr=true}})'
```

Runtime settings reset when the config reloads. Check each option with
`hyprctl getoption` and `hyprctl configerrors`. Persist only changes supported by
the comparison. Avoid changing VRR, bit depth, explicit sync, CPU scheduling,
and kernel parameters together: that loses the evidence needed for a source fix.
