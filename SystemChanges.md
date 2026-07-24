# System Changes

This document inventories custom system and hardware behavior on this laptop as
of July 22, 2026. It distinguishes root-installed configuration from Niri and
Quickshell user-session behavior. The active desktop is Niri with Quickshell;
the retained Sway and Waybar configurations are not included.

## Configuration Ownership

- Files under `system/` are source copies for root-owned files under `/etc` and
  `/usr`. They are not deployed with GNU Stow.
- Files under `niri/`, `quickshell/`, `gtklock/`, `swayosd/`, `wlogout/`, and
  other Stow packages are user-session configuration linked under `$HOME`.
- Files under `/etc/asusd/` are runtime configuration owned and updated by
  `asusd`. They are documented here but are not tracked in this repository.
- Package-generated NVIDIA and Supergfx module configuration is documented
  separately and is not managed by the `system/` tree.

## Installed Root-Level Changes

The following repository copies are currently installed as root-owned files.
The installed content matches the repository content; `/etc/supergfxd.conf`
differs only by a missing final newline.

| Repository source | Installed path | Mode | Purpose |
|---|---|---:|---|
| `system/etc/systemd/logind.conf.d/90-sleep-policy.conf` | `/etc/systemd/logind.conf.d/90-sleep-policy.conf` | `0644` | Physical key and lid policy |
| `system/etc/systemd/sleep.conf.d/90-hibernate-delay.conf` | `/etc/systemd/sleep.conf.d/90-hibernate-delay.conf` | `0644` | Suspend-then-hibernate timing |
| `system/usr/lib/systemd/system-sleep/asus-keyboard-backlight` | `/usr/lib/systemd/system-sleep/asus-keyboard-backlight` | `0755` | Keyboard-backlight restoration |
| `system/usr/libexec/asus-power-profile-sync` | `/usr/libexec/asus-power-profile-sync` | `0755` | AC/battery profile selection |
| `system/etc/systemd/system/asus-power-profile-sync.service` | `/etc/systemd/system/asus-power-profile-sync.service` | `0644` | Serialized profile synchronization |
| `system/etc/udev/rules.d/90-asus-power-profile-sync.rules` | `/etc/udev/rules.d/90-asus-power-profile-sync.rules` | `0644` | Charger event integration |
| `system/usr/lib/systemd/system-sleep/asus-power-profile-sync` | `/usr/lib/systemd/system-sleep/asus-power-profile-sync` | `0755` | Profile synchronization after resume |
| `system/etc/supergfxd.conf` | `/etc/supergfxd.conf` | `0644` | Safe GPU-mode transition policy |

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

The repository does not configure the swap file, resume offset, firmware, or
kernel support required for hibernation. The policy enables and requests the
behavior but cannot guarantee that platform hibernation is functional.

### Sleep hooks

Before every sleep, `asus-keyboard-backlight` saves
`leds:asus::kbd_backlight` through `systemd-backlight`. After resume it waits
0.5 seconds and restores the saved level because the firmware can reset it
after hibernation. Save and restore errors are intentionally non-fatal.

After every resume, `asus-power-profile-sync` force-checks the current power
source and reapplies the configured ASUS AC or battery profile. This catches a
charger change that happened while the machine was asleep.

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

## AC And Battery Power Profiles

### Profile ownership

`asusd` is the automatic AC/battery policy authority. The standard
`power-profiles-daemon` remains enabled for its D-Bus API, application holds,
and manual profile selection, but its battery-aware automatic switching is
disabled to prevent two daemons from racing to change the same platform
profile.

Current state:

- `powerprofilesctl query-battery-aware`: `False`
- Saved ASUS AC default: `Balanced`
- Saved ASUS battery default: `Quiet`
- Current profile while this inventory was taken: `Balanced`
- ASUS platform profiles are linked to CPU energy-performance preferences.

The profile mapping used by Quickshell is:

| Quickshell label | `powerprofilesctl` profile | ASUS profile |
|---|---|---|
| Power Saver | `power-saver` | `Quiet` |
| Balanced | `balanced` | `Balanced` |
| Performance | `performance` | `Performance` |

Selecting an active profile calls `powerprofilesctl set`. Selecting an AC or
battery default calls `asusctl profile set --ac` or
`asusctl profile set --battery`; this updates daemon-owned state under
`/etc/asusd/`.

### Charger and resume synchronization

`90-asus-power-profile-sync.rules` starts
`asus-power-profile-sync.service` for add/change events on power-supply devices
that expose an `online` attribute. The helper:

1. Serializes calls with `flock` under `/run/asus-power-profile-sync/`.
2. Waits one second for charger state to settle.
3. Treats any online `Mains`, `USB`, `USB_C`, or `USB_PD` source as AC.
4. Reads the saved defaults from `asusctl profile get`.
5. Applies the matching default with `asusctl profile set`.
6. Avoids duplicate event-driven changes when the aggregate source is
   unchanged.

The resume hook uses force mode, so it reapplies the correct profile even when
the recorded power source has not changed. The oneshot service is static and
normally appears as `inactive (dead)` after successful execution; that state is
expected. Logs confirm successful Quiet-on-battery and Balanced-on-AC changes.

## ASUS Runtime Settings

These current settings are stored by `asusd` under `/etc/asusd/` and are not
reproducible from the tracked `system/` files alone:

- Battery charge limit: 80%.
- Disable NVIDIA powerd on battery: enabled.
- AC profile: Balanced.
- Battery profile: Quiet.
- Quiet EPP: Power.
- Balanced EPP: BalancePower.
- Performance and Custom EPP: Performance.
- Custom CPU fan curves are enabled for Balanced and Quiet profiles.
- GPU and MID custom fan curves are disabled for all saved profiles.
- Performance custom fan curves are disabled.
- Keyboard Aura brightness is Off; its configured mode is Static.
- The ASUS Slash display is disabled.

The exact fan curve points are stored in `/etc/asusd/fan_curves.ron`.
Quickshell's fan panel is monitor-only and polls once per second while visible.
It reads measured CPU, GPU, and MID RPM across every ASUS profile, distinguishes
a valid stopped fan from an unavailable sensor, and does not modify fan curves.
MID is RPM-only because its controlling temperature is not exposed. Every card
always shows measured RPM. CPU/GPU add a secondary target calculated only from
an enabled custom curve and an available controlling temperature; disabled
curves are identified as firmware-controlled rather than being presented as an
inaccurate percentage. Persistent cards are not recreated by each telemetry
sample, avoiding interaction flicker during polling.

NVIDIA temperature is queried only when its PCI runtime state is already
active. Integrated mode reports the dGPU disabled, and a runtime-suspended
Hybrid dGPU reports suspended without being woken. NVIDIA hwmon is preferred;
`nvidia-smi` is restricted to dGPU MUX mode, where NVIDIA cannot
runtime-suspend.

## GPU Mode Management

`/etc/supergfxd.conf` currently defines:

- Saved mode: `Hybrid`.
- VFIO support: disabled.
- Force every transition to reboot: disabled.
- Logind integration: enabled.
- Logout timeout: 180 seconds.
- Hotplug handling: ASUS.

The live Supergfx mode was `Hybrid` when this inventory was taken, and
`supergfxd.service` was active.

Quickshell exposes three modes:

| UI mode | Supergfx mode | Firmware expectation | Required action |
|---|---|---|---|
| Integrated | `Integrated` | dGPU disabled, iGPU display path | Logout when switching to/from Hybrid |
| Hybrid | `Hybrid` | AMD display path with NVIDIA offload | Logout when switching to/from Integrated |
| dGPU | `AsusMuxDgpu` | NVIDIA MUX display path | Reboot when entering or leaving |

Before allowing a mode change, the helpers verify that `supergfxd` is active,
`always_reboot` is false, no Supergfx or ASUS Armoury operation is pending, and
the reported mode matches `dgpu_disable` and `gpu_mux_mode`. A confirmed
request records a transition marker under
`${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/`.

Hybrid/Integrated requests are prepared without calling Supergfx while Niri is
still using NVIDIA device files. After a second confirmation, the action helper
starts `gpu-mode-apply-after-logout.sh` as a transient user service outside the
graphical session and terminates only the current session. The worker waits for
that session and its compositor to fully exit, revalidates the request, and only
then calls Supergfx. This avoids Supergfx's logout timeout and prevents Niri
from blocking NVIDIA module removal. The worker verifies both the reported mode
and ASUS firmware state before marking the transition complete. If logind stops
the transient user service after logout, the next power-state poll reconciles
the applying marker against live Supergfx and firmware state, clearing it on
success or reporting that the source mode was restored.

dGPU MUX transitions retain Supergfx's reboot workflow. Logout and reboot are
never automatic: both require separate confirmation. The marker is reconciled
with live firmware and Supergfx state after the next login.

`supergfxctl` is intentionally the only GPU-mode controller. GPU mode changes
through ROG Control Center or `asusctl armoury` can queue conflicting writes to
the same firmware attributes and are treated as an error by Quickshell.

## NVIDIA And Backlight Driver State

These installed settings are generated by Supergfx or the NVIDIA package, not
tracked by this repository:

- `/etc/modprobe.d/supergfxd.conf` blacklists Nouveau, enables NVIDIA DRM
  modesetting, and forces `nvidia-wmi-ec-backlight`.
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

The Quickshell power panel can select 60 Hz or 120 Hz. The bar changes
brightness in 5% increments, and Niri's hardware brightness keys use the same
runtime-selected backlight through SwayOSD. SwayOSD has a 5% minimum for its
hardware-key path and shows percentage overlays.

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
| `power-profiles-daemon.service` | Enabled | Active, battery-aware switching disabled |
| `supergfxd.service` | Enabled | Active |
| `asus-power-profile-sync.service` | Static, event-driven oneshot | Inactive after each successful run |

The profile synchronizer is started by udev and manually during installation;
it does not need and does not provide a normal `[Install]` enablement target.

## Deployment And Maintenance

After changing a tracked root-level file, reinstall its repository copy with
the ownership and mode listed above. Then apply the relevant operation:

| Changed component | Required operation |
|---|---|
| systemd service unit | `sudo systemctl daemon-reload` |
| udev rule | `sudo udevadm control --reload` |
| Profile synchronizer | `sudo systemctl start asus-power-profile-sync.service` |
| logind policy | `sudo systemctl reload systemd-logind.service` |
| Supergfx configuration | `sudo systemctl restart supergfxd.service` |

To keep `asusd` as the only automatic power-source policy authority without
producing an error when already configured:

```bash
if powerprofilesctl query-battery-aware | grep -q ': True$'; then
  sudo powerprofilesctl configure-battery-aware --disable
fi
```

Useful diagnostics:

```bash
systemd-analyze cat-config systemd/logind.conf
systemd-analyze cat-config systemd/sleep.conf
systemctl status asus-power-profile-sync.service asusd.service \
  power-profiles-daemon.service supergfxd.service
powerprofilesctl query-battery-aware
powerprofilesctl get
asusctl profile get
supergfxctl --get
```

## Important Caveats

- `system/` is not a Stow package; editing the repository copy does not update
  the installed root-owned file until it is reinstalled.
- Hibernation depends on system support outside this repository.
- ASUS profile parsing depends on the current English `asusctl profile get`
  output labels.
- The GPU helper depends on ASUS WMI firmware attributes and Supergfx output.
- The display helper intentionally fails instead of guessing when connector or
  backlight discovery is ambiguous.
- GPU temperature is queried only when NVIDIA is already active, avoiding an
  accidental wake of a suspended Hybrid dGPU.
- Logout from the lock screen or wlogout terminates all sessions for the user;
  GPU-transition logout terminates only the current session.
