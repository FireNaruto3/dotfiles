# How Everything Works

This document explains the runtime architecture of the desktop managed by this
repository: which process starts each component, how data moves between them,
which state is persistent, and what happens when something fails. `README.md`
contains installation and usage instructions. `SystemChanges.md` inventories
root-installed policy and machine-local ASUS state.

The repository does not define how the display manager initially starts Niri.
It assumes Niri is launched as a Wayland session with a working user systemd
manager and D-Bus session.

## Runtime Overview

```text
display manager or session launcher
└─ Niri
   ├─ apply-theme.sh --start quickshell
   │  ├─ generate the Matugen palette
   │  └─ exec Quickshell's normal shell
   ├─ apply-theme.sh --start mako
   │  ├─ wait for the Matugen generation lock
   │  └─ exec Mako with its generated configuration
   ├─ awww-daemon
   ├─ Waypaper wallpaper restoration
   ├─ text and image clipboard watchers
   ├─ initial display-brightness setup
   └─ swayidle

lock request
└─ lock.sh
   └─ quickshell-lock-shell.service
      └─ LockShell.qml
         ├─ acquire the Wayland session lock
         ├─ report protocol security through IPC
         └─ authenticate through PAM before unlocking

suspend request
└─ systemd-suspend.service
   ├─ quickshell-secure-suspend precondition
   │  └─ quickshell-secure-lock.service
   │     └─ lock.sh
   ├─ systemd sleep hooks
   └─ kernel suspend
```

## Configuration Ownership

Most top-level directories are GNU Stow packages. Their paths mirror locations
under `$HOME`; for example, `niri/.config/niri/config.kdl` is linked to
`~/.config/niri/config.kdl`. Niri, Quickshell, Matugen, Waypaper, Wlogout, Mako,
Rofi, Ghostty, and the user scripts run from these user-owned links.

The `system/` directory is different. Its files are source copies for
root-owned destinations under `/etc` and `/usr`. They have no system effect
until they are installed with the commands and modes in `README.md`. Editing a
repository copy does not automatically update its installed counterpart.

Files under `/etc/asusd` are mutable state owned by `asusd` and `asusctl`. They
are not installed from this repository. The tracked system service and the
documented Aura command recreate specific policy, while charge limits, fan
curves, effects, and other daemon state remain machine-local.

## Session Startup

Niri's startup commands are defined in
`niri/.config/niri/config.kdl`. Niri starts the components independently, so
most of them do not have a strict ordering relationship.

### Theme And Shell Startup

Niri starts these commands:

```sh
$HOME/.config/matugen/apply-theme.sh --start quickshell
$HOME/.config/matugen/apply-theme.sh --start mako
```

Both commands resolve the current Waypaper wallpaper and attempt to generate
the same Matugen outputs. `apply-theme.sh` serializes generation with
`~/.cache/matugen/apply.lock`, so the two processes cannot write those files at
the same time. The lock is released before either long-running process starts.

If the wallpaper is missing or Matugen is unavailable, startup is degraded but
not blocked: the script still starts Quickshell or Mako. Quickshell has built-in
colors, Niri's generated include is optional, and Mako falls back to its normal
configuration lookup.

### Other Startup Processes

Niri also starts:

| Process | Purpose |
|---|---|
| `awww-daemon` | Owns desktop wallpaper rendering and transitions |
| `waypaper --restore --no-post-command` | Restores the saved wallpaper without regenerating the theme a second time |
| `wl-paste --type text --watch cliphist ...` | Stores text clipboard entries |
| `wl-paste --type image --watch cliphist ...` | Stores image clipboard entries |
| `display-control.sh set-brightness 50%` | Sets the initial internal-panel brightness |
| `swayidle -w ...` | Runs dim, lock, display-power, and suspend timers |

When Niri runs as a session, normal XDG autostart processing also applies. The
optional `autostart` Stow package starts NetBird UI and suppresses Blueman's
packaged applet. Bluetooth management remains available from Quickshell.

## Niri And Display Handling

Niri owns window placement, workspaces, input, output configuration, startup,
and keybindings. The built-in Samsung `ATNA40CU05-0` panel is matched by EDID
identity rather than a probe-order connector name. It starts at 2880x1800,
approximately 60 Hz, scale 1.75.

`display-control.sh` discovers the current Niri output, DRM connector, GPU, and
backlight at runtime. It intentionally fails instead of guessing if discovery
is ambiguous. Refresh switching accepts only a uniquely advertised 2880x1800
mode matching the requested rounded rate.

Niri includes `~/.cache/matugen/niri.kdl` with `optional=true`. The static focus
colors remain usable if that generated file is absent. Niri live-reloads the
generated include when Matugen replaces it.

The physical power key is deliberately not handled by Niri. The installed
systemd-logind policy owns physical power, sleep, and lid events.

## The Normal Quickshell Process

`quickshell/.config/quickshell/shell.qml` is the normal shell entry point. It is
separate from the lock-shell process and is not part of the session's security
boundary.

The normal shell creates one bar for every output reported by Quickshell. The
bar starts as a left rail and can switch to a top horizontal layout for the
current process lifetime. Orientation, open drawers, and selected screen are
in-memory state and reset when Quickshell restarts.

The shell provides:

- Workspaces and focused-window state from Niri's JSON event stream.
- StatusNotifier system tray hosting.
- Volume, microphone, brightness, media, and keyboard-lock OSDs.
- Clock, media, calendar, DND, unified quick-settings, and power drawers.
- Network, Bluetooth, battery, CPU, memory, audio, and brightness indicators.
- The Flameshot tray process.

The dedicated quick-settings button sits after clipboard history and before the
Bluetooth control. Its Bluetooth, network, audio, and display pages follow the
same order as their bar controls; the individual controls open their matching
page directly.

### Niri Event Stream

`NiriData.qml` runs `niri msg --json event-stream` and maintains in-memory maps
of workspaces and windows. It determines the active window on each output's
active workspace. Malformed events are ignored with a warning. If the stream
exits, Quickshell starts it again after one second.

Workspace actions are sent back through `niri msg action` rather than modifying
compositor state directly.

### General System Polling

`SystemData.qml` runs `scripts/system-stats.sh` every five seconds. That helper
collects NetworkManager, BlueZ, PipeWire, keyboard-lock, display brightness,
ASUS keyboard brightness, UPower, battery-health, uptime, and Mako DND data into
one JSON object.

CPU usage, CPU temperature, and memory use a lighter `resource-stats.sh` poll
every two seconds. ASUS keyboard brightness has a separate 400 ms poll so
hardware-key changes can display an OSD promptly. Invalid JSON leaves the
previous QML values intact rather than replacing them with incomplete state.

Detailed quick-settings and power polling is demand-driven. Quick settings
uses `quick-settings.sh` as an argument-safe adapter for NetworkManager, BlueZ,
WirePlumber, and Niri outputs. These collectors run only while their
corresponding drawer is visible.

### Hardware Keys And OSD

Niri keybindings call `scripts/osd-control.sh`. The script first applies the
hardware action with `wpctl`, `brightnessctl`, `asusctl`, or `playerctl`, then
sends a best-effort IPC request to the normal Quickshell process. If the OSD is
unavailable, the hardware action can still succeed.

While the session is locked, the microphone key queries the lock shell's secure
state. A secure lock forces the microphone muted instead of toggling it. Other
configured hardware keys remain available while locked.

### Tray And Resources

Quickshell hosts StatusNotifier tray items and owns the configured
`~/.local/bin/flameshot-v14` tray process. `F6` launches the Flameshot capture
interface separately.

The Resources button is a toggle: it terminates an existing user-owned
`resources` process or asks Niri to spawn a new one. Detailed monitoring stays
in Resources instead of adding more high-frequency bar polling.

## Dynamic Themes And Wallpapers

Matugen reads its templates from `~/.config/matugen/templates` and writes:

| Output | Consumer |
|---|---|
| `~/.cache/matugen/quickshell.json` | Normal and lock Quickshell processes |
| `~/.cache/matugen/niri.kdl` | Niri |
| `~/.cache/matugen/mako` | Mako |
| `~/.cache/matugen/rofi.rasi` | Rofi |
| `~/.config/ghostty/themes/Matugen` | Ghostty |
| `~/.cache/matugen/waypaper.css` | Waypaper |
| `~/.cache/matugen/wlogout.css` | Wlogout |

These cache consumers intentionally use the fixed `~/.cache/matugen` path;
`XDG_CACHE_HOME` does not relocate them.

When Waypaper selects a wallpaper, `awww` changes the desktop wallpaper and the
configured post-command runs `apply-theme.sh --reload-waypaper`. Matugen then
rebuilds all outputs. Quickshell and Niri watch their generated files, Mako and
Ghostty receive reload requests, and new Rofi and Wlogout instances use the new
colors.

An open Waypaper window is restarted after generation because its GTK CSS
provider does not watch the stylesheet. The restart is detached so the Matugen
script can exit.

The lock-screen wallpaper is independent. `LockShell.qml` scans
`~/dotfiles/wallpapers` and stores its selection through Quickshell state. A
lock wallpaper change does not alter the desktop wallpaper or regenerate the
palette.

## Locking And Authentication

All normal lock entry points call
`~/.config/quickshell/scripts/lock.sh`: the Niri keybinding, swayidle, Wlogout,
and the suspend guard.

### Lock Acquisition Handshake

`lock.sh` performs these steps:

1. Query the lock IPC endpoint and return immediately if a secure lock already
   exists.
2. Serialize concurrent requests with
   `$XDG_RUNTIME_DIR/quickshell-lock.lock` and a bounded `flock` wait.
3. Recheck security after acquiring the serialization lock.
4. Reset any previous failed state and start
   `quickshell-lock-shell.service` through the user systemd manager.
5. Read the unit's exact `MainPID`.
6. Poll that process through the `lock isSecure` IPC method.
7. Return success only when the Wayland session-lock protocol reports secure.

Every IPC call is bounded. If acquisition times out or the process exits, a
unit started by that invocation is stopped and the helper returns failure.

### Why There Are Two User Units

`quickshell-lock-shell.service` owns the long-running process:

```text
qs -n -p ~/.config/quickshell/LockShell.qml
```

`quickshell-secure-lock.service` is a bounded oneshot that calls `lock.sh`. The
separation allows the acquisition service to finish without systemd terminating
the lock UI that must remain alive until unlock.

These are system-wide user-unit definitions installed under `/etc/systemd/user`,
but each invocation runs inside the selected user's manager and session.

### Wayland Lock And PAM

`LockShell.qml` creates `WlSessionLock`. Security is based on its `secure`
property, not on whether a lock-looking window is visible. An internal timer
exits if protocol security is not established within 9.8 seconds.

Unlock uses the dedicated `/etc/pam.d/quickshell-lock` policy, which requires
local `pam_unix` authentication and account validation. Password data is held
only for the active authentication attempt and cleared when it completes.

After successful authentication, the shell releases the Wayland lock, waits
150 ms, and exits. Failed authentication keeps the lock active and reports an
incorrect-password, maximum-attempt, or PAM-service error.

The lock screen polls Caps Lock every 500 ms and UPower battery state every ten
seconds. It does not run the normal shell's heavier system polling.

## Idle, Suspend, And Resume

The swayidle timeline is:

| Idle time | Action |
|---:|---|
| 270 seconds | Save internal-display brightness and dim to 10% |
| Activity after dimming | Restore the saved brightness |
| 300 seconds | Run the lock helper |
| 400 seconds | Ask Niri to power off monitors |
| Activity after display-off | Ask Niri to power monitors on |
| 500 seconds | Request `systemctl suspend` |

The swayidle `lock` event also calls the same lock helper. Its `before-sleep`
event holds a logind delay inhibitor until that helper has securely acquired the
Wayland session lock, before logind pauses Niri's device access.

### Suspend Is Fail-Closed

Every systemd suspend passes through the installed
`systemd-suspend.service` drop-in. Its `ExecStartPre` runs
`/usr/libexec/quickshell-secure-suspend` before the kernel sleep operation as a
final fail-closed check after swayidle's pre-sleep lock.

The helper searches logind for an active, local Wayland session. If logind
temporarily clears the active marker while preparing a lid-close suspend, the
helper accepts the sole local Wayland session but rejects an ambiguous choice.
It reconstructs that user's runtime-directory and D-Bus environment, then
starts `quickshell-secure-lock.service` as the session owner. The entire
operation has a 14-second bound.

If no suitable session exists, the lock service fails, or the Wayland protocol
never reports secure, the helper logs an auth-private error, attempts a critical
desktop notification, and returns nonzero. Systemd then aborts suspend. This
prevents an unlocked desktop from being exposed after resume.

### Physical Sleep Policy

The installed logind drop-in maps the physical power key, sleep key, and lid
close on battery or AC to ordinary suspend. Docked lid close is ignored. Niri
does not duplicate physical power-key handling.

Hibernation is intentionally unused because Secure Boot kernel lockdown reports
it unavailable on this machine.

### Keyboard Backlight Across Sleep

The system-sleep hook reads the ASUS keyboard LED level before sleep and saves
it in the root-only runtime file `/run/asus-keyboard-backlight.state`. After
resume it waits for the sysfs device, clamps the saved value to the current
maximum, restores it, and removes the runtime file.

Backlight save or restore failures are nonfatal; they must not prevent the
machine from sleeping or waking. The persistent Aura policy separately disables
the firmware sleep animation while retaining boot, awake, and shutdown
lighting.

A separate system-sleep hook temporarily limits the visible kernel console to
critical messages while the machine sleeps and restores its previous level
after resume. Resume diagnostics remain in the journal, but transient ASUS ACPI
firmware errors no longer appear before Niri redraws the lock screen.

## Power And Battery Management

The power drawer polls only while open. `PowerData.qml` and `power-state.sh`
read the current standard power profile, supported display refresh rates, ASUS
keyboard brightness, and battery charge threshold.

The drawer applies one action at a time:

| Setting | Command path |
|---|---|
| Active power profile | `powerprofilesctl set` |
| Charge limit | `asusctl battery limit` |
| Keyboard lighting level | `asusctl leds set` |
| Display refresh | `display-control.sh set-refresh` |

The standard active profile and ASUS source-dependent defaults are related but
separate. The enabled `asus-power-profile-sync.service` configures `asusd` to
select Balanced on AC and Quiet on battery, detects the current source under
`/sys/class/power_supply`, and applies its matching profile. `asusd` handles
later plug and unplug events. A system-sleep hook runs the same reconciliation
after resume in case the source changed while suspended. A manual Quickshell
selection uses `powerprofilesctl` and does not rewrite the ASUS defaults.

Bar battery state comes from UPower's display device. Power draw and health are
calculated from present system batteries under `/sys/class/power_supply`.

The installed UPower policy marks 20% low, 5% critical, and 2% action. Its
critical action is power off because hibernation is unavailable.

## GPU Mode Changes

`~/.local/bin/gpu-mode` manages ASUS firmware attributes rather than unloading
drivers from the live desktop.

| Mode | `dgpu_disable` | `gpu_mux_mode` |
|---|---:|---:|
| Integrated | 1 | 1 |
| Hybrid | 0 | 1 |
| Ultimate | 0 | 0 |

A mode-changing request verifies required commands and services, serializes
requests with a runtime lock, rejects pre-existing queued state, and prompts for
confirmation unless `--yes` was supplied. It queues both firmware values
through `asusctl`, verifies both over D-Bus, and requests an immediate reboot.

`asusd` keeps queued values in memory. `asus-shutdown` applies them only after
graphical users have exited. If the second write, verification, or reboot
request fails, `gpu-mode` attempts to neutralize the queue by restoring the
current firmware values.

`gpu-mode --get` prints the configured mode. `gpu-mode status` reports
configured and queued values, PCI runtime state, and relevant services.

## Logout, Shutdown, And Wlogout

The lock screen requires confirmation for every power action. Restart, power
off, and logout additionally require successful PAM authentication. Sleep does
not ask for a second password because the session is already securely locked
and the suspend precondition verifies that state again.

| Lock-screen action | Command |
|---|---|
| Restart | `systemctl reboot` |
| Sleep | `systemctl suspend` |
| Power off | `systemctl poweroff` |
| Log out | `loginctl terminate-user "$USER"` |

The bar launches Wlogout through `launch-wlogout.sh`. The launcher uses the
generated Matugen stylesheet when present and falls back to normal Wlogout
stylesheet discovery otherwise.

Wlogout uses the same lock helper and the same systemd reboot, power-off, and
user-wide logout commands. Unlike lock-screen restart, power-off, and logout,
Wlogout does not invoke the dedicated Quickshell PAM context. Authorization
beyond Wlogout depends on system policy.

`loginctl terminate-user` ends every session belonging to the account. Niri's
`Ctrl+Alt+Delete` binding is different: it asks only the compositor to quit.

## Notifications, Clipboard, And Portals

Mako starts with the generated Matugen configuration. The clock drawer toggles
Mako's do-not-disturb mode. Theme regeneration asks Mako to reload without
restarting it.

Separate text and image `wl-paste` watchers feed `cliphist`. The clipboard
picker lists entries through Rofi, decodes the selection, and copies it back to
the Wayland clipboard. Clearing history requires confirmation, wipes `cliphist`,
and clears the current clipboard. Clipboard history can contain sensitive data;
this repository does not configure encryption or the database location.

The Niri portal preference selects GNOME first with GTK fallback, forces GTK
for Access and Notification, and uses GNOME Keyring for Secret. The portal
backends and keyring are package-managed; their service activation is not
defined by this repository.

## State And Lifetime

### Persistent Tracked State

- Stow-managed application and desktop configuration.
- Wallpapers under `~/dotfiles/wallpapers`.
- Root policy after files from `system/` are installed.

### Generated State

- Matugen outputs under `~/.cache/matugen`.
- Ghostty's generated `~/.config/ghostty/themes/Matugen` theme.
- These can be regenerated from the selected wallpaper and templates.

### Persistent Mutable State

- Waypaper's selected desktop wallpaper in its configuration.
- Lock wallpaper through `Quickshell.statePath("lockscreen.json")`.
- Clipboard history managed by `cliphist`.
- ASUS daemon state under `/etc/asusd`.
- Firmware GPU mode after a successful reboot transition.

### Ephemeral State

- Bar orientation, open drawers, OSD state, and polled data.
- `$XDG_RUNTIME_DIR/quickshell-lock.lock`.
- `$XDG_RUNTIME_DIR/gpu-mode.lock`.
- `/run/asus-keyboard-backlight.state` during a sleep cycle.
- Queued GPU values held in `asusd` memory.
- Running Niri, Quickshell, lock shell, Mako, awww, clipboard, and swayidle
  processes.

## Failure And Security Properties

- Suspend fails closed if the active Wayland session cannot be secured.
- A visible lock screen is not trusted; the Wayland protocol's secure state is.
- Lock IPC, serialization, acquisition, user-service startup, and suspend
  orchestration are time-bounded.
- The normal Quickshell bar and the security-sensitive lock shell are separate
  processes.
- PAM uses a dedicated local-password policy.
- Display discovery fails instead of selecting ambiguous hardware.
- GPU transitions are reboot-only and verified before reboot.
- Root policy is inactive until repository files are installed under `/etc` or
  `/usr`.
- Wlogout power actions do not have the lock screen's additional PAM layer.
- User-wide logout affects every session for the account.
- The lock helper secures the first active local Wayland session found by the
  suspend precondition; multi-seat selection is not implemented.

## Troubleshooting Order

When a workflow fails, check it from owner to consumer:

1. Validate Niri with `niri validate -c niri/.config/niri/config.kdl`.
2. Confirm the expected process is running with `systemctl`, `systemctl --user`,
   or `pgrep`.
3. Confirm Stow links point to this repository and root-installed files match
   their `system/` sources.
4. Check generated files under `~/.cache/matugen` before debugging consumers.
5. Read the relevant user and system journals for the current boot.
6. For suspend, inspect `systemd-suspend.service`,
   `quickshell-secure-lock.service`, and `quickshell-lock-shell.service` together.
7. For hardware controls, run the corresponding helper directly and inspect its
   explicit discovery or command error.
8. For GPU mode changes, use `gpu-mode status` before issuing another request.

Do not launch `LockShell.qml` as a casual syntax check. It attempts to acquire
the real Wayland session lock.
