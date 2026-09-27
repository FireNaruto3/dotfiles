# System Changes

This document inventories behavior managed by files in this repository. It
distinguishes root-installed configuration from Niri and Quickshell user-session
behavior. It intentionally excludes observed host state, package-managed files,
and mutable settings stored by external services.

## Configuration Ownership

- Files under `system/` are source copies for root-owned files under `/etc` and
  `/usr`. They are not deployed with GNU Stow.
- Files under `niri/`, `quickshell/`, `wlogout/`, and
  other Stow packages are user-session configuration linked under `$HOME`.
- The base NVIDIA module packages remain package-managed. The ASUS-specific
  module policy is tracked under `system/`.

## Installed Root-Level Changes

The following repository copies are installed as root-owned files.

| Repository source | Installed path | Mode | Purpose |
|---|---|---:|---|
| `system/etc/systemd/logind.conf.d/90-sleep-policy.conf` | `/etc/systemd/logind.conf.d/90-sleep-policy.conf` | `0644` | Physical key and lid policy |
| `system/etc/UPower/UPower.conf` | `/etc/UPower/UPower.conf` | `0644` | Critical-battery thresholds and power-off action |
| `system/etc/pam.d/quickshell-lock` | `/etc/pam.d/quickshell-lock` | `0644` | Dedicated local-password PAM policy for the lock shell |
| `system/etc/systemd/user/quickshell-secure-lock.service` | `/etc/systemd/user/quickshell-secure-lock.service` | `0644` | Bounded user-service lock acquisition |
| `system/etc/systemd/system/systemd-suspend.service.d/90-quickshell-secure-lock.conf` | `/etc/systemd/system/systemd-suspend.service.d/90-quickshell-secure-lock.conf` | `0644` | Block suspend unless the Wayland lock is secure |
| `system/etc/systemd/system/asus-power-profile-sync.service` | `/etc/systemd/system/asus-power-profile-sync.service` | `0644` | Configure native ASUS AC and battery profiles |
| `system/usr/lib/systemd/system-sleep/asus-keyboard-backlight` | `/usr/lib/systemd/system-sleep/asus-keyboard-backlight` | `0755` | Keyboard-backlight restoration |
| `system/usr/libexec/quickshell-secure-suspend` | `/usr/libexec/quickshell-secure-suspend` | `0755` | Find the active Wayland user and request a secure lock |
| `system/etc/modprobe.d/asus-nvidia.conf` | `/etc/modprobe.d/asus-nvidia.conf` | `0644` | Static NVIDIA and ASUS backlight policy |

## Sleep And Secure Boot

### Physical controls and lid

`system/etc/systemd/logind.conf.d/90-sleep-policy.conf` makes logind handle:

| Event | Action |
|---|---|
| Physical power key | Suspend |
| Physical sleep key | Suspend |
| Lid close on battery | Suspend |
| Lid close on external power | Suspend |
| Lid close while docked | Ignore |

Niri uses `disable-power-key-handling`, leaving the physical power key under
logind control rather than handling it a second time in the compositor. Lid
switch handling remains active even when an application holds an inhibitor.

### Secure Boot constraint

This machine's policy assumes Secure Boot integrity lockdown, where the kernel
disables disk hibernation. `AllowHibernation=yes` cannot override that kernel
restriction.

The active policy therefore uses ordinary suspend everywhere. The former
`90-hibernate-delay.conf` drop-in is removed, and no static `resume=` or
`resume_offset=` kernel parameters are installed. This preserves the Secure
Boot trust model instead of weakening lockdown to restore hibernation.

### Sleep hooks

Before every sleep, `asus-keyboard-backlight` validates and saves the ASUS
keyboard LED level in a root-only runtime file. After resume it waits for the
sysfs device, clamps the saved value to the current maximum, restores it, and
removes the runtime state. Save and restore errors are intentionally non-fatal.

The `systemd-suspend.service` drop-in runs `quickshell-secure-suspend` before
suspend. The helper locates an active local Wayland session and starts the
user-level `quickshell-secure-lock.service` with a bounded timeout. Suspend is
aborted and an auth-private journal error is emitted if no suitable session is
available or the Wayland session lock is not secured within roughly 10 seconds.

## Idle And Lock Behavior

Niri starts `swayidle` with the following user-session timeline:

| Idle time | Behavior |
|---:|---|
| 270 seconds | Save display brightness and dim the internal panel to 10% |
| Activity after dimming | Restore the saved brightness |
| 300 seconds | Lock with the Quickshell lock helper |
| 400 seconds | Power off displays |
| Activity after display-off | Power displays back on |
| 500 seconds | Run `systemctl suspend` |
| Before any sleep | Lock before the system enters sleep |

The lock helper serializes concurrent requests with `flock`, reuses an already
secure instance, starts the separate `LockShell.qml` Quickshell instance, and
polls its `lock isSecure` IPC method for roughly 10 seconds. It terminates a
failed instance and returns an error if the Wayland session-lock protocol is not
secured within that time.

The lock screen requires confirmation before these system actions. Restart,
power off, and logout additionally require successful authentication through
the dedicated `quickshell-lock` PAM policy:

| Action | Command |
|---|---|
| Restart | `systemctl reboot` |
| Sleep | `systemctl suspend` |
| Power off | `systemctl poweroff` |
| Log out | `loginctl terminate-user "$USER"` |

The wlogout menu uses the same Quickshell lock helper, reboot and power-off
commands, and user-wide logout. `Ctrl+Alt+Delete` is different: it invokes
Niri's compositor quit action.

## Power Profiles

The standard `power-profiles-daemon` provides the active power-profile API.
Quickshell exposes Power Saver, Balanced, and Performance and applies a selected
profile with `powerprofilesctl set`. The enabled
`asus-power-profile-sync.service` configures `asusd` to use Balanced on AC and
Quiet on battery; `asusd` then handles power-source events natively.

## Critical Battery Policy

The tracked UPower configuration uses percentage-based thresholds: low at 20%,
critical at 5%, and action at 2%. The critical action is power off rather than
an unavailable or unsafe sleep mode.

## ASUS Monitoring

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

Deployment requires `supergfxd.service` to remain disabled because its live
driver unload and PCI removal paths are unreliable on this laptop and conflict
with ASUS firmware-managed transitions. Quickshell uses `gpu-mode --get` only
to select a safe temperature telemetry path; it does not queue or apply
graphics-mode changes.

## NVIDIA And Backlight Driver State

The repository-owned `/etc/modprobe.d/asus-nvidia.conf` blacklists Nouveau,
enables NVIDIA DRM modesetting, and forces `nvidia-wmi-ec-backlight`. NVIDIA
package configuration and kernel command-line state are outside this
repository's scope.

## Display And Brightness Behavior

The internal panel is matched by EDID identity as Samsung
`ATNA40CU05-0`, configured at 2880x1800 with scale 1.75. Niri defaults to
approximately 60 Hz at login for lower power consumption.

`quickshell/.config/quickshell/scripts/display-control.sh` discovers the
current connector, DRM card, and backlight at runtime instead of assuming
names such as `eDP-1`, `card1`, or `amdgpu_bl1`. It exposes only supported
2880x1800 refresh modes; this panel advertises 60 Hz and 120 Hz.

The Quickshell power panel can select 60 Hz or 120 Hz. The bar and Niri's
hardware brightness keys change the runtime-selected backlight in 5% increments
with a 5% minimum. Quickshell provides the bottom-center hardware-key OSD for
display and keyboard brightness, volume, microphone mute, media playback, and
keyboard-lock state.

The ASUS keyboard backlight can be changed among Off, Low, Medium, and High
through `asusctl`.

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

## Deployment And Maintenance

After changing a tracked root-level file, reinstall its repository copy with
the ownership and mode listed above. Then apply the relevant operation:

| Changed component | Required operation |
|---|---|
| logind policy | `sudo systemctl reload systemd-logind.service` |
| UPower policy | `sudo systemctl restart upower.service` |
| System or user unit | `sudo systemctl daemon-reload` or `systemctl --user daemon-reload`, as applicable |
| ASUS profile defaults | `sudo systemctl enable --now asus-power-profile-sync.service` |
| Removed hibernation policy | Move the obsolete file aside with the guarded commands in `README.md` |
| ASUS NVIDIA module policy | Regenerate the initramfs when applicable, then reboot before relying on changed module options |

`systemctl daemon-reload` does not apply modprobe changes. Use the
distribution's normal initramfs tooling if module configuration is included in
the boot image.

Useful diagnostics:

```bash
systemd-analyze cat-config systemd/logind.conf
systemd-analyze cat-config systemd/sleep.conf
busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanSuspend
busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate
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
- Hibernation remains disabled while Secure Boot enforces kernel lockdown.
- The display helper intentionally fails instead of guessing when connector or
  backlight discovery is ambiguous.
- GPU temperature is queried only in dGPU MUX mode; Hybrid telemetry reads only
  PCI runtime state.
- ASUS GPU requests are intentionally in-memory until shutdown. Restarting
  `asusd.service` cancels a queued request before it is applied.
- Logout from the lock screen or wlogout terminates all sessions for the user.
