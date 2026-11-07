# Desktop Architecture

This guide explains the active login, session, shell, locking, suspend, and
hardware-control paths. Installation commands and package requirements live in
the [README](../README.md); root-installed files and current machine-local state
are inventoried in [System Changes](SystemChanges.md).

## Configuration Ownership

Most top-level directories are GNU Stow packages. Their paths mirror `$HOME`, so
`niri/.config/niri/config.kdl` becomes `~/.config/niri/config.kdl`. Changes to a
linked repository file are immediately visible to its user-session consumer.

`system/` is different. It contains source copies for root-owned files under
`/etc` and `/usr`; editing a repository copy has no system effect until it is
installed with the ownership and mode documented in the README. Mutable files
under `/etc/asusd` belong to `asusd`, not this repository.

## Boot, Login, And Recovery

The active boot path is:

```text
systemd
├─ getty@tty1.service (recovery console)
└─ ly@tty2.service
   └─ Ly login through PAM
      ├─ authenticate the local account
      ├─ start and unlock GNOME Keyring
      └─ niri-session
         └─ Niri
```

Ly 1.5.0 is an upstream-built, Wayland-only display manager. Its binary,
support files, and `ly@.service` are installed outside this repository; the
repository owns its configuration and PAM policy. Automatic login, empty
passwords, shell sessions, and X11 sessions are disabled. Ly discovers the
packaged `/usr/share/wayland-sessions/niri.desktop` entry and starts
`niri-session`, rather than invoking bare `niri`.

TTY2 belongs to Ly, while TTY1 remains an ordinary text login. If graphical
login fails, switch to `Ctrl+Alt+F1` and inspect:

```bash
systemctl status ly@tty2.service
journalctl -u ly@tty2.service
/usr/bin/ly --validate-config /etc/ly/config.ini
test -f /usr/share/wayland-sessions/niri.desktop
```

The console uses a 14x28 Terminus font for the 2880x1800 panel. Ly binds F1 to
shutdown, F2 to restart, F6 to password visibility, and F7/F8 to the
runtime-discovered internal-panel backlight helper.

### PAM And GNOME Keyring

PAM is the system authentication framework. Ly uses the `ly` PAM service, which
includes Ubuntu's normal `login` stack for authentication, account policy,
password changes, and session setup. Optional GNOME Keyring hooks reuse the
login password and start the keyring daemon, avoiding a second keyring prompt
when its password matches the account password.

Initial login and screen unlock are separate security boundaries:

| Operation | Program | PAM service | Result |
|---|---|---|---|
| Initial login | Ly | `ly` | Creates the logind and Niri session; starts keyring |
| Unlock | Quickshell lock shell | `quickshell-lock` | Verifies the existing user and releases the existing lock |

The lock policy intentionally contains only local password and account checks;
it does not open another login session or start another keyring daemon.

## Niri Session Startup

`niri-session` establishes the user systemd manager, D-Bus environment, XDG
session variables, autostart processing, and portal environment. Niri then
starts:

| Process | Purpose |
|---|---|
| `apply-theme.sh --start quickshell` | Generate colors, then start the bar, drawers, OSD, and shell data sources |
| `apply-theme.sh --start mako` | Generate colors, then start notifications |
| `/usr/libexec/xfce-polkit` | Display graphical PolicyKit authentication prompts |
| `awww-daemon` | Render wallpapers and transitions |
| `waypaper --restore --no-post-command` | Restore the selected wallpaper without regenerating twice |
| `display-control.sh set-brightness 50%` | Initialize internal-panel brightness |
| `swayidle` | Dim, lock, power off displays, and suspend on idle |

XDG autostart additionally starts NetBird UI and suppresses Blueman's applet;
Bluetooth controls remain in Quickshell. The Cloudflare WARP daemon remains a
system service, but its graphical taskbar user service is disabled.

### Portals, PolicyKit, And Keyring

These retained GNOME components do not imply a GNOME Shell session:

- GNOME and GTK portal backends provide file selection, screen sharing,
  notifications, and sandbox access.
- GNOME Keyring stores secrets and implements the Secret portal.
- `xfce-polkit` presents password dialogs when PolicyKit requires authorization
  for a privileged operation.

PAM answers whether authentication is valid; PolicyKit answers whether an
authenticated user may perform a particular privileged action.

## Quickshell And Desktop Data

The normal entry point is `quickshell/.config/quickshell/shell.qml`. It creates
one bar per output and is separate from the security-sensitive lock process.
The bar can switch between a left rail and top layout for the current process
lifetime and provides:

- Niri workspaces, focused-window state, and system tray items.
- Bluetooth, network, audio, brightness, battery, CPU, RAM, and clock status.
- Clock, Quick Settings, and power drawers.
- Volume, microphone, brightness, keyboard-lighting, profile, touchpad, media,
  and keyboard-lock OSDs.

`NiriData.qml` consumes `niri msg --json event-stream`. General status is
collected by `system-stats.sh`; CPU, AMD `Tctl`, and RAM use the lighter
`resource-stats.sh`. Detailed Quick Settings and power collection runs only
while its drawer is open. Hardware keybindings first apply their action through
the appropriate command and then make a best-effort Quickshell IPC call, so a
failed OSD does not prevent the hardware change.

Both CPU and RAM controls toggle the external Resources application. Niri's
built-in interactive screenshot UI is bound to `Mod+Shift+S` (Fn+F6 on this
laptop); it copies captures to the clipboard and saves them through the
configured screenshot path.

## Themes And Wallpapers

At startup, `apply-theme.sh` resolves Waypaper's selected wallpaper and
serializes Matugen generation with `~/.cache/matugen/apply.lock`. Generated
colors are consumed by Quickshell, Niri, Mako, Rofi, Ghostty, Waypaper, and
Wlogout. Quickshell and Niri watch their generated files; Mako and Ghostty are
explicitly reloaded. Waypaper is restarted after a wallpaper change because its
GTK stylesheet is not watched.

If the wallpaper or Matugen is unavailable, startup continues with static or
normal fallback configuration. The lock-screen wallpaper is selected and stored
independently and does not regenerate the desktop palette.

## Locking And Suspend

All lock entry points use `~/.config/quickshell/scripts/lock.sh`, including the
Niri binding, swayidle, Wlogout, and the system suspend guard.

```text
lock request
└─ lock.sh
   ├─ serialize requests with a bounded flock
   ├─ start or reuse quickshell-lock-shell.service
   ├─ read the unit's exact MainPID
   └─ poll lock isSecure through bounded IPC
      └─ return success only after Wayland session-lock security
```

`quickshell-lock-shell.service` owns `LockShell.qml` until unlock.
`quickshell-secure-lock.service` is a bounded oneshot used by system-level
suspend orchestration. A visible lock surface alone is not trusted: security is
based on acquisition of the Wayland session-lock protocol.

The idle sequence is:

| Idle time | Action |
|---:|---|
| 270 seconds | Save brightness and dim the internal panel to 10% |
| 300 seconds | Acquire the secure lock |
| 400 seconds | Power off displays |
| 500 seconds | Request suspend |

Activity restores brightness or display power. Swayidle's `before-sleep` action
holds a logind delay inhibitor while acquiring the lock. Every suspend also
passes through `/usr/libexec/quickshell-secure-suspend`, which locates the active
local Wayland session and starts the bounded lock service as that user. If the
session is ambiguous or the protocol lock cannot be confirmed, systemd aborts
suspend rather than allowing an unlocked resume.

Logind handles the physical power key, sleep key, and lid. Battery and AC lid
close suspend; docked lid close is ignored. Hibernation is intentionally unused
because Secure Boot kernel lockdown reports it unavailable.

## Power And ASUS Hardware

The Quickshell power drawer operates on demand:

| Setting | Command path |
|---|---|
| Active profile | `powerprofilesctl set` |
| Charge threshold | `asusctl battery limit` |
| Keyboard brightness | `asusctl leds set` |
| Internal refresh rate | `display-control.sh set-refresh` |

`asus-power-profile-sync.service` is a boot-time oneshot ordered after `asusd`
and `power-profiles-daemon`. It configures Balanced on AC and Quiet on battery,
then applies the profile matching an online `Mains` supply. USB source-port
entries are deliberately ignored. `asusd` handles later power-source events,
and a resume hook reconciles the profile if the source changed during sleep.

Another sleep hook preserves the ASUS keyboard-backlight level. The installed
UPower policy marks 20% low, 5% critical, and 2% action, with power-off as the
critical action. The NVIDIA module policy disables Nouveau, enables NVIDIA DRM
modesetting, and forces the ASUS NVIDIA backlight driver.

`gpu-mode` queues verified ASUS firmware attributes and reboots; it does not
unload GPU drivers from the live desktop. Integrated, Hybrid, and Ultimate map
to `dgpu_disable` and `gpu_mux_mode`. `asus-shutdown` applies queued values only
after graphical sessions exit.

## Session And Power Actions

The lock screen confirms every action. Restart, power-off, and logout also
require successful `quickshell-lock` authentication; sleep relies on the
already-secure lock and the suspend precondition. Wlogout exposes equivalent
commands but does not add the lock screen's PAM step.

| Action | Command |
|---|---|
| Restart | `systemctl reboot` |
| Sleep | `systemctl suspend` |
| Power off | `systemctl poweroff` |
| Log out | `loginctl terminate-user "$USER"` |

Logout terminates every session for the user. Niri's `Ctrl+Alt+Delete` action
only exits the compositor.

## State And Troubleshooting

Tracked state is the repository configuration. Matugen outputs and the Ghostty
theme are generated. Waypaper selection, lock wallpaper, `/etc/asusd` settings,
and firmware GPU mode are persistent mutable state. Runtime locks, queued GPU
values, open drawers, OSD state, and bar orientation are ephemeral.

Troubleshoot from owner to consumer:

1. Validate Niri and Ly.
2. Confirm Ly, Niri, Quickshell, Mako, portals, keyring, and PolicyKit processes.
3. Check Stow links and compare installed root files with `system/` sources.
4. Inspect `~/.cache/matugen` before debugging theme consumers.
5. Read `/var/log/ly.log`, `~/.local/state/ly-session.log`, and relevant system
   or user journals.
6. For suspend, inspect `systemd-suspend.service`,
   `quickshell-secure-lock.service`, and `quickshell-lock-shell.service` together.
7. For GPU changes, run `gpu-mode status` before issuing another request.

Do not launch `LockShell.qml` as a syntax check: it attempts to acquire the real
Wayland session lock.
