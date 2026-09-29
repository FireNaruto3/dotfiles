# System Changes

This document inventories behavior managed by files in this repository. It
distinguishes root-installed configuration from Niri and Quickshell user-session
behavior. Relevant mutable ASUS state is documented separately as an observed
machine-local snapshot; it is not presented as repository-managed policy.

## Configuration Ownership

- Files under `system/` are source copies for root-owned files under `/etc` and
  `/usr`. They are not deployed with GNU Stow.
- Files under `niri/`, `quickshell/`, `wlogout/`, and
  other Stow packages are user-session configuration linked under `$HOME`.
- The base NVIDIA module packages remain package-managed. The ASUS-specific
  module policy is tracked under `system/`.
- Files under `/etc/asusd` are generated and mutated by `asusd`/`asusctl`. They
  are not copied from this repository and must be reviewed or recreated on a
  new installation.

## Installed Root-Level Changes

The following repository copies are installed as root-owned files.

| Repository source | Installed path | Mode | Purpose |
|---|---|---:|---|
| `system/etc/systemd/logind.conf.d/90-sleep-policy.conf` | `/etc/systemd/logind.conf.d/90-sleep-policy.conf` | `0644` | Physical key and lid policy |
| `system/etc/UPower/UPower.conf` | `/etc/UPower/UPower.conf` | `0644` | Critical-battery thresholds and power-off action |
| `system/etc/pam.d/quickshell-lock` | `/etc/pam.d/quickshell-lock` | `0644` | Dedicated local-password PAM policy for the lock shell |
| `system/etc/systemd/user/quickshell-lock-shell.service` | `/etc/systemd/user/quickshell-lock-shell.service` | `0644` | Own the lock-shell process until the user unlocks |
| `system/etc/systemd/user/quickshell-secure-lock.service` | `/etc/systemd/user/quickshell-secure-lock.service` | `0644` | Bounded user-service lock acquisition |
| `system/etc/systemd/system/systemd-suspend.service.d/90-quickshell-secure-lock.conf` | `/etc/systemd/system/systemd-suspend.service.d/90-quickshell-secure-lock.conf` | `0644` | Block suspend unless the Wayland lock is secure |
| `system/etc/systemd/system/asus-power-profile-sync.service` | `/etc/systemd/system/asus-power-profile-sync.service` | `0644` | Configure and reconcile ASUS AC and battery profiles |
| `system/usr/lib/systemd/system-sleep/asus-keyboard-backlight` | `/usr/lib/systemd/system-sleep/asus-keyboard-backlight` | `0755` | Keyboard-backlight restoration |
| `system/usr/lib/systemd/system-sleep/asus-power-profile-sync` | `/usr/lib/systemd/system-sleep/asus-power-profile-sync` | `0755` | ASUS profile reconciliation after resume |
| `system/usr/lib/systemd/system-sleep/quiet-resume-console` | `/usr/lib/systemd/system-sleep/quiet-resume-console` | `0755` | Suppress transient firmware errors on the visible resume console |
| `system/usr/libexec/asus-power-profile-sync` | `/usr/libexec/asus-power-profile-sync` | `0755` | Apply the ASUS profile matching the current power source |
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
The persistent ASUS Aura policy disables the keyboard's firmware sleep animation
while retaining boot, awake, and shutdown lighting; apply it with
`asusctl aura power keyboard --boot --awake --shutdown`.

`quiet-resume-console` saves the current kernel console log level, temporarily
limits the visible console to critical messages across sleep, and restores the
previous level after resume. Kernel and firmware messages remain available in
the journal; this only prevents the ACPI firmware error burst from appearing
before Niri regains DRM access and redraws the lock screen.

The `systemd-suspend.service` drop-in runs `quickshell-secure-suspend` before
suspend. The helper locates an active local Wayland session and starts the
user-level `quickshell-secure-lock.service` with a bounded timeout. It accepts
the sole local Wayland session if logind temporarily clears its active marker
during lid-close processing, but rejects an ambiguous choice. Suspend is aborted
and an auth-private journal error is emitted if no suitable session is available
or the Wayland session lock is not secured within the timeout.

Swayidle's `before-sleep` hook acquires the secure lock while holding logind's
delay inhibitor, before logind pauses Niri's DRM access. The system suspend
precondition remains the final fail-closed verification.

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

Before any sleep request, swayidle runs the lock helper and waits for secure
Wayland lock acquisition before releasing its logind delay inhibitor.

The lock helper serializes concurrent requests with `flock`, reuses an already
secure instance, starts `quickshell-lock-shell.service`, and polls that unit's
exact Quickshell process through the `lock isSecure` IPC method. The separate
long-running unit owns the lock process until the user unlocks; the bounded
acquisition unit can therefore exit without killing the lock UI. IPC calls and
lock contention are bounded so concurrent requests cannot stall suspend. The
systemd suspend precondition performs this check before every sleep and aborts
suspend if the Wayland session-lock protocol is not secured within the timeout.

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
Quiet on battery, then explicitly applies the profile matching the current power
source. `asusd` handles later plug and unplug events natively. A system-sleep
hook reapplies the matching profile after resume in case the source changed
while suspended. A manual profile selected through Quickshell changes only the
current `power-profiles-daemon` profile; it does not rewrite either ASUS default
and can be replaced by a later power-source event or resume reconciliation.

## Mutable ASUS State

The ASUS daemon owns `/etc/asusd/*.ron`. These files are machine-local runtime
configuration, not source files installed from this repository. The tracked
`asus-power-profile-sync.service` reproducibly sets the AC and battery profile
defaults and reconciles the active profile; the Aura command in `README.md`
reproducibly sets only the keyboard power-state policy. Quickshell can
subsequently change the charge limit and keyboard brightness through `asusctl`.

Observed state on 2026-09-29:

- `/etc/asusd/asusd.ron` uses an 80% charge limit, disables NVIDIA powerd on
  battery, links platform profiles to EPP, selects Balanced on AC and Quiet on
  battery, and has no AC/DC profile-tuning groups enabled.
- `/etc/asusd/aura_19b6.ron` has Aura brightness Off and Rainbow Wave selected;
  its stored built-in colors remain red. Keyboard lighting is enabled at boot,
  while awake, and during shutdown; the sleep animation is disabled.
- `/etc/asusd/slash.ron` has the Slash display disabled. Its stored event flags
  remain enabled but have no effect while the display itself is disabled.
- `/etc/asusd/fan_curves.ron` enables the CPU custom curve in Quiet and
  Balanced, and all three CPU/GPU/MID curves in Performance. The stored points
  are shown below; disabled curves remain present but firmware-controlled.

| Profile | Fan | Enabled | Temperatures (C) | PWM values |
|---|---|---|---|---|
| Quiet | CPU | yes | 45, 50, 60, 63, 66, 70, 74, 80 | 0, 41, 61, 69, 74, 88, 101, 127 |
| Quiet | GPU | no | 50, 67, 68, 70, 70, 70, 70, 70 | 1, 38, 53, 66, 76, 86, 107, 107 |
| Quiet | MID | no | 43, 49, 70, 72, 74, 76, 78, 78 | 2, 26, 51, 58, 58, 127, 130, 130 |
| Balanced | CPU | yes | 47, 62, 65, 68, 70, 72, 74, 76 | 1, 43, 48, 58, 68, 94, 114, 140 |
| Balanced | GPU | no | 50, 59, 62, 65, 67, 69, 71, 73 | 1, 53, 66, 76, 86, 107, 135, 160 |
| Balanced | MID | no | 50, 62, 65, 68, 70, 72, 74, 76 | 1, 51, 58, 58, 94, 130, 188, 242 |
| Performance | CPU | yes | 20, 64, 66, 68, 70, 72, 74, 76 | 43, 48, 58, 94, 114, 130, 150, 186 |
| Performance | GPU | yes | 20, 57, 60, 63, 66, 69, 72, 75 | 53, 66, 76, 107, 135, 150, 170, 209 |
| Performance | MID | yes | 20, 64, 66, 68, 70, 72, 74, 76 | 51, 58, 58, 130, 188, 198, 237, 237 |

Use `asusctl` rather than editing these files directly. Recheck the daemon-owned
files after changing charge, fan, lighting, Slash, or profile settings; their
contents may change across `asusd` versions.

## Critical Battery Policy

The tracked UPower configuration uses percentage-based thresholds: low at 20%,
critical at 5%, and action at 2%. The critical action is power off rather than
an unavailable or unsafe sleep mode.

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
names such as `eDP-1`, `card1`, or `amdgpu_bl1`. The power drawer exposes only
supported 2880x1800 refresh modes; this panel advertises 60 Hz and 120 Hz. The
unified Displays page separately enumerates each enabled Niri output's advertised
modes at the output's current resolution.

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

The bar's lightweight CPU indicator reads utilization and, when available, the
AMD `k10temp` sensor labeled `Tctl`. It does not poll dGPU telemetry. Both CPU
and RAM indicators toggle the external Resources application for detailed
monitoring.

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
| ASUS profile policy | `sudo systemctl enable --now asus-power-profile-sync.service` |
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
- ASUS GPU requests are intentionally in-memory until shutdown. Restarting
  `asusd.service` cancels a queued request before it is applied.
- Logout from the lock screen or wlogout terminates all sessions for the user.
