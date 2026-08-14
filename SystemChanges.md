# System Changes

This document inventories custom system and hardware behavior on this laptop as
of August 14, 2026. It distinguishes root-installed configuration from Niri and
Quickshell user-session behavior. The active desktop is Niri with Quickshell;
the retained Sway and Waybar configurations are not included.

## Configuration Ownership

- Files under `system/` are source copies for root-owned files under `/etc` and
  `/usr`. They are not deployed with GNU Stow.
- Files under `niri/`, `quickshell/`, `gtklock/`, `wlogout/`, and
  other Stow packages are user-session configuration linked under `$HOME`.
- Files under `/etc/asusd/` are runtime configuration owned and updated by
  `asusd`. They are documented here but are not tracked in this repository.
- The base NVIDIA module packages remain package-managed. The ASUS-specific
  module policy is tracked under `system/`.

## Installed Root-Level Changes

The following repository copies are installed as root-owned files.

| Repository source | Installed path | Mode | Purpose |
|---|---|---:|---|
| `system/etc/systemd/logind.conf.d/90-sleep-policy.conf` | `/etc/systemd/logind.conf.d/90-sleep-policy.conf` | `0644` | Physical key and lid policy |
| `system/etc/systemd/sleep.conf.d/90-hibernate-delay.conf` | `/etc/systemd/sleep.conf.d/90-hibernate-delay.conf` | `0644` | Suspend-then-hibernate timing |
| `system/usr/lib/systemd/system-sleep/asus-keyboard-backlight` | `/usr/lib/systemd/system-sleep/asus-keyboard-backlight` | `0755` | Keyboard-backlight restoration |
| `system/etc/modprobe.d/asus-nvidia.conf` | `/etc/modprobe.d/asus-nvidia.conf` | `0644` | Static NVIDIA and ASUS backlight policy |

## Sleep And Hibernate

### Physical controls and lid

`system/etc/systemd/logind.conf.d/90-sleep-policy.conf` makes logind handle:

| Event | Action |
|---|---|
| Physical power key | Suspend, then hibernate |
| Physical sleep key | Suspend, then hibernate |
| Lid close on battery | Suspend, then hibernate |
| Lid close on external power | Suspend, then hibernate |
| Lid close while docked | Ignore |

Niri uses `disable-power-key-handling`, leaving the physical power key under
logind control rather than handling it a second time in the compositor.

### Hibernate timing

`system/etc/systemd/sleep.conf.d/90-hibernate-delay.conf` enables hibernation
and suspend-then-hibernate with these settings:

- The laptop initially suspends.
- It transitions from suspend to hibernation after 30 minutes.
- The hibernation transition is allowed while connected to AC power.
- The machine currently has a 20 GiB `/swap.img` swap file enabled.

Hibernation uses systemd's dynamic `HibernateLocation` EFI variable. Systemd
discovers the active `/swap.img`, records its backing device and physical
offset before hibernating, and lets the initrd consume that EFI metadata on the
next boot. Static `resume=` and `resume_offset=` kernel parameters are
intentionally absent. On an ordinary boot without a hibernation image, both
`/sys/power/resume` and `/sys/power/resume_offset` should be zero.

A static-resume configuration was tested and removed on July 24, 2026. Dracut
resolved the correct backing partition and attempted resume during initrd, but
after finding no image the kernel reset `/sys/power/resume` to `0:0` while
leaving the nonzero offset in `/sys/power/resume_offset`. Systemd 259 classifies
that state as `SLEEP_RESUME_MISCONFIGURED`, making hibernation unavailable.
Dynamic EFI resume avoids that invalid normal-boot state and matches the setup
that successfully hibernated on July 15, 2026.

Direct hibernation was validated again on kernel `7.0.0-28-generic` on July 24,
2026. The kernel logged hibernation entry and exit in the same boot, systemd
reported success, and the NVIDIA and ASUS resume hooks completed. After a
successful hibernate/resume cycle, `/sys/power/resume` contains `259:7` and
`/sys/power/resume_offset` contains `59015168`; systemd populated these values
dynamically from the active swap file.

### Sleep hooks

Before every sleep, `asus-keyboard-backlight` saves
`leds:asus::kbd_backlight` through `systemd-backlight`. After resume it waits
0.5 seconds and restores the saved level because the firmware can reset it
after hibernation. Save and restore errors are intentionally non-fatal.

## Idle And Lock Behavior

Niri starts `swayidle` with the following user-session timeline:

| Idle time | Behavior |
|---:|---|
| 270 seconds | Save display brightness and dim the internal panel to 10% |
| Activity after dimming | Restore the saved brightness |
| 300 seconds | Lock with the Quickshell lock helper |
| 400 seconds | Power off displays |
| Activity after display-off | Power displays back on |
| 500 seconds | Run `systemctl suspend-then-hibernate` |
| Before any sleep | Lock before the system enters sleep |

The lock helper starts the separate `LockShell.qml` Quickshell instance and
polls its `lock isSecure` IPC method for roughly 10 seconds. If the Wayland
session-lock protocol is not secured, it falls back to `gtklock`.

The lock screen requires confirmation before these system actions:

| Action | Command |
|---|---|
| Restart | `systemctl reboot` |
| Sleep | `systemctl suspend-then-hibernate` |
| Power off | `systemctl poweroff` |
| Log out | `loginctl terminate-user "$USER"` |

The wlogout menu uses the same Quickshell lock helper, reboot and power-off
commands, and user-wide logout. `Ctrl+Alt+Delete` is different: it invokes
Niri's compositor quit action.

## Power Profiles

The standard `power-profiles-daemon` provides the active power-profile API.
Quickshell exposes Power Saver, Balanced, and Performance and applies a selected
profile with `powerprofilesctl set`. The panel does not configure separate AC
or battery defaults, and this repository does not install a charger-event or
resume synchronizer.

## ASUS Runtime Settings

These current settings are stored by `asusd` under `/etc/asusd/` and are not
reproducible from the tracked `system/` files alone:

- Battery charge limit: 80%.
- Disable NVIDIA powerd on battery: enabled.
- Quiet EPP: Power.
- Balanced EPP: BalancePower.
- Performance and Custom EPP: Performance.
- Custom CPU fan curves are enabled for Balanced and Quiet profiles.
- GPU and MID custom fan curves are disabled for all saved profiles.
- Performance custom fan curves are disabled.
- Keyboard Aura brightness is Off; its configured mode is Static.
- The ASUS Slash display is disabled.

The exact fan curve points are stored in `/etc/asusd/fan_curves.ron`.
Quickshell's fan panel is monitor-only and polls live sensors once per second
while visible. It reads measured CPU, GPU, and MID RPM across every ASUS
profile, distinguishes a valid stopped fan from an unavailable sensor, and does
not modify fan curves. Active-profile and curve metadata is refreshed every 15
seconds rather than on every live sample.
MID is RPM-only because its controlling temperature is not exposed. Every card
always shows measured RPM. CPU/GPU add a secondary target calculated only from
an enabled custom curve and an available controlling temperature; disabled
curves are identified as firmware-controlled rather than being presented as an
inaccurate percentage. Persistent cards are not recreated by each telemetry
sample, avoiding interaction flicker during polling.

NVIDIA temperature is queried only in dGPU MUX mode. Integrated mode reports
the dGPU disabled, while Hybrid reports its PCI runtime state without reading
NVIDIA telemetry, so polling cannot wake the dGPU or delay runtime suspension.
NVIDIA hwmon is preferred; `nvidia-smi` is the MUX-mode fallback.

## ASUS Graphics Modes

Graphics modes are controlled by the `dgpu_disable` and `gpu_mux_mode` ASUS
firmware attributes exposed through `asusd`:

| Mode | `dgpu_disable` | `gpu_mux_mode` |
|---|---:|---:|
| Integrated | 1 | 1 |
| Hybrid | 0 | 1 |
| Ultimate | 0 | 0 |

The `scripts` Stow package installs `~/.local/bin/gpu-mode`. It reads current
attributes and writes requested values through `asusctl`, inspects the queued
values over D-Bus with `busctl`, rejects partial or conflicting queues, and
requires an immediate reboot for every transition. It requires compatible
Armoury support in `asusctl`/`asusd`, an active `asus-shutdown.service`, and
`flock` for request serialization. `asusd` holds requested GPU values in memory;
`asus-shutdown` applies them only after logind and graphical GPU users have
exited. Failed verification or a rejected reboot request causes the command to
overwrite the queue with the current firmware values.

`supergfxd.service` is disabled because its live driver unload and PCI removal
paths are unreliable on this laptop and conflict with ASUS firmware-managed
transitions. Quickshell uses `gpu-mode --get` only to select a safe temperature
telemetry path; it does not queue or apply graphics-mode changes.

## NVIDIA And Backlight Driver State

The repository-owned `/etc/modprobe.d/asus-nvidia.conf` blacklists Nouveau,
enables NVIDIA DRM modesetting, and forces `nvidia-wmi-ec-backlight`. The
following settings are generated by the NVIDIA package and are not tracked:

- `/etc/modprobe.d/nvidia-graphics-drivers-kms.conf` enables NVIDIA DRM
  modesetting and preserves NVIDIA video memory across suspend/resume using
  `/var` for temporary storage.
- `/etc/modules-load.d/nvidia.conf` requests `nvidia`, `nvidia_modeset`,
  `nvidia_uvm`, and `nvidia_drm` modules.
- The current kernel command line includes `acpi_backlight=native`.

## Display And Brightness Behavior

The internal panel is matched by EDID identity as Samsung
`ATNA40CU05-0`, configured at 2880x1800 with scale 1.75. Niri defaults to
approximately 60 Hz at login for lower power consumption.

`quickshell/.config/quickshell/scripts/display-control.sh` discovers the
current connector, DRM card, and backlight at runtime instead of assuming
names such as `eDP-1`, `card1`, or `amdgpu_bl1`. It exposes only supported
2880x1800 refresh modes and currently reports 60 Hz and 120 Hz. The live mode
was 60 Hz when this inventory was taken.

The Quickshell power panel can select 60 Hz or 120 Hz. The bar and Niri's
hardware brightness keys change the runtime-selected backlight in 5% increments
with a 5% minimum. Quickshell provides the bottom-center hardware-key OSD for
display and keyboard brightness, volume, microphone mute, media playback, and
keyboard-lock state.

The ASUS keyboard backlight can be changed among Off, Low, Medium, and High
through `asusctl`. Its live level was Off when this inventory was taken.

## Battery And Hardware Controls

The Quickshell power panel additionally provides:

- Battery charge threshold from 20% to 100% in 5% increments through
  `asusctl battery limit`.
- ASUS keyboard-backlight level through `asusctl leds set`.
- Internal panel refresh selection through Niri.
- Read-only fan RPM, temperature, custom-curve state, and interpolated curve
  percentage.

Battery, backlight, connector, and DRM device names are discovered at runtime
where possible. The display and ASUS controls remain machine-specific to this
laptop's hardware.

## Active Services And Expected States

| Service | Enablement | Expected runtime state |
|---|---|---|
| `asusd.service` | Static/D-Bus activated | Active |
| `asus-shutdown.service` | Part of `asusd.service` | Active |
| `power-profiles-daemon.service` | Enabled | Active |
| `supergfxd.service` | Disabled | Inactive |

## Deployment And Maintenance

After changing a tracked root-level file, reinstall its repository copy with
the ownership and mode listed above. Then apply the relevant operation:

| Changed component | Required operation |
|---|---|
| logind policy | `sudo systemctl reload systemd-logind.service` |
| ASUS NVIDIA module policy | Regenerate the initramfs when applicable, then reboot before relying on changed module options |

`systemctl daemon-reload` does not apply modprobe changes. Use the
distribution's normal initramfs tooling if module configuration is included in
the boot image.

Useful diagnostics:

```bash
systemd-analyze cat-config systemd/logind.conf
systemd-analyze cat-config systemd/sleep.conf
systemctl status asusd.service asus-shutdown.service power-profiles-daemon.service
systemctl is-enabled supergfxd.service
systemctl is-active supergfxd.service
powerprofilesctl get
asusctl profile get
gpu-mode status
modprobe --showconfig | grep -E '^(blacklist nouveau|options (nvidia-drm|nvidia-wmi-ec-backlight))'
```

## Important Caveats

- `system/` is not a Stow package; editing the repository copy does not update
  the installed root-owned file until it is reinstalled.
- Hibernation depends on system support outside this repository.
- The display helper intentionally fails instead of guessing when connector or
  backlight discovery is ambiguous.
- GPU temperature is queried only in dGPU MUX mode; Hybrid telemetry reads only
  PCI runtime state.
- ASUS GPU requests are intentionally in-memory until shutdown. Restarting
  `asusd.service` cancels a queued request before it is applied.
- Logout from the lock screen or wlogout terminates all sessions for the user.
