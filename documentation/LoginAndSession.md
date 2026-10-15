# Login And Session Guide

This guide explains how this machine boots into Niri, how login authentication
works, why some GNOME components remain installed, how locking differs from
logging in, and how to recover if the graphical login stops working. It is
written as both a description of the current setup and a refresher on the Linux
components involved.

For the broader desktop architecture, see
[How Everything Works](HowEverythingWorks.md). For an inventory of files copied
into `/etc` and `/usr`, see [System Changes](SystemChanges.md).

## What Changed

The desktop previously used GDM and parts of the GNOME session to reach Niri:

```text
systemd
└─ GDM
   ├─ GNOME login screen
   └─ Niri session
```

It now uses Ly:

```text
systemd
└─ Ly on TTY2
   ├─ PAM authenticates the login
   ├─ GNOME Keyring is unlocked
   └─ niri-session
      └─ Niri desktop
```

The migration did the following:

1. Built Ly 1.5.0 from pinned upstream source commit
   `bccddcda3290c6286b5cb6e5eea9910d65c5f178` with Zig 0.17.0.
2. Built Ly with `-Doptimize=ReleaseSafe -Denable_x11_support=false` so this is a
   Wayland-only installation.
3. Installed Ly's binary, support files, and systemd unit from upstream.
4. Added repository-owned Ly configuration and PAM policy.
5. Configured Ly to run on TTY2 and retained TTY1 as a recovery console.
6. Integrated GNOME Keyring into the Ly login.
7. Confirmed that Ly discovers and launches the packaged `niri-session` entry.
8. Added `xfce-polkit` to Niri startup for graphical authorization prompts.
9. Tested a reboot and a login/logout/login cycle before removing GDM.
10. Removed GDM, GNOME Shell, and unused GNOME session components.
11. Retained portals, keyring support, selected GNOME applications, and core
    desktop services used by the Niri session.
12. Removed the stale `display-manager.service` symlink left pointing at GDM.
13. Reviewed, but did not blindly apply, the remaining APT autoremove proposal.

## The Complete Boot Chain

The startup sequence is:

```text
Firmware/UEFI
└─ bootloader
   └─ Linux kernel
      └─ systemd
         ├─ system services
         ├─ getty@tty1.service for recovery
         └─ ly@tty2.service
            └─ Ly
               └─ PAM login
                  ├─ account authentication
                  ├─ GNOME Keyring startup/unlock
                  └─ niri-session
                     └─ Niri
```

`systemd` is the system and service manager. It starts and supervises services
such as networking, Bluetooth, audio, login, power management, and Ly.

Ly is enabled directly under `multi-user.target` through a link equivalent to:

```text
/etc/systemd/system/multi-user.target.wants/ly@tty2.service
    -> /usr/lib/systemd/system/ly@.service
```

There is intentionally no `display-manager.service` alias. Ly's upstream unit
is enabled directly and does not require that alias. The old alias pointed to
the removed `gdm3.service`, so it was deleted after GDM was purged.

## TTY1 And TTY2

A TTY is a Linux virtual console. They are usually reached with key combinations
such as `Ctrl+Alt+F1`, `Ctrl+Alt+F2`, and `Ctrl+Alt+F3`.

| Console | Purpose |
|---|---|
| TTY1 | Recovery text login |
| TTY2 | Ly and the Niri graphical session |
| Other TTYs | Additional consoles when provided by systemd |

Ly owns TTY2. Its unit conflicts with the ordinary `getty@tty2.service`, so the
normal text login prompt on TTY2 is disabled. `getty@tty1.service` remains
enabled independently.

If Ly or Niri fails, switch to TTY1:

```text
Ctrl+Alt+F1
```

Log in with the normal Linux username and password, then inspect the service:

```bash
systemctl status ly@tty2.service
journalctl -u ly@tty2.service
```

TTY1 is deliberately kept available when changing Ly or PAM because a bad login
configuration can prevent graphical login.

## What Ly Does

Ly is the display manager. A display manager has three main responsibilities:

1. Show a login interface.
2. Ask the operating system to authenticate the user.
3. Start the selected desktop session after authentication succeeds.

Ly does not implement Linux password verification itself. It identifies itself
as the PAM service named `ly`, then asks PAM to authenticate the login.

The repository copy of Ly's configuration is:

```text
system/etc/ly/config.ini
```

Its installed, root-owned copy is:

```text
/etc/ly/config.ini
```

Important settings include:

```ini
allow_empty_password = false
auto_login_session = null
auto_login_user = null
service_name = ly
shell = false
session_log = .local/state/ly-session.log
```

These settings reject empty passwords, disable automatic login, use the `ly`
PAM service, disable arbitrary shell sessions, and save session output under the
user's local state directory.

Ly discovers Wayland sessions from desktop files such as:

```text
/usr/share/wayland-sessions/niri.desktop
```

It executes the command declared by that file. For Niri, this is the packaged
`niri-session` launcher rather than a bare `niri` command.

### Ly Controls

The login screen intentionally retains these controls:

| Key | Action |
|---|---|
| F1 | Shut down |
| F2 | Restart |
| F5 | Lower brightness |
| F6 | Raise brightness |
| F7 | Show or hide the entered password |

These are available at the physical login screen before authentication.

## PAM Explained

PAM means **Pluggable Authentication Modules**. It is the standard framework
used by Linux programs that need to authenticate users or open login sessions.

Programs that commonly use PAM include:

- Ly and GDM
- `sudo`
- Console login
- SSH servers
- Screen lockers
- PolicyKit
- Password-changing tools

The core idea is:

> An application asks PAM whether an operation should succeed, and PAM applies
> the authentication rules configured for that application.

For example, Ly does not need to know how `/etc/shadow`, account expiry, keyring
passwords, or future authentication modules work. It asks the `ly` PAM service
and receives success or failure.

### PAM Operation Types

PAM separates authentication into four major operation types:

| Type | Purpose |
|---|---|
| `auth` | Verify identity, normally by checking a password |
| `account` | Decide whether the account is currently allowed to log in |
| `password` | Coordinate password changes |
| `session` | Perform work when opening or closing a login session |

A password can be correct while the account phase still refuses login. Examples
include an expired account, an expired password, or an administrative access
restriction.

### The Ly PAM Policy

The repository copy is `system/etc/pam.d/ly`; its installed copy is
`/etc/pam.d/ly`. Its important structure is:

```pam
auth       include      login
-auth      optional     pam_gnome_keyring.so

account    include      login

password   include      login
-password  optional     pam_gnome_keyring.so use_authtok

session    include      login
-session   optional     pam_gnome_keyring.so auto_start
```

`auth include login` delegates password authentication to Ubuntu's normal login
stack. That stack eventually uses modules such as `pam_unix.so` for local Unix
passwords.

```text
Password entered in Ly
        ↓
Ly passes it to PAM
        ↓
Ubuntu's login PAM stack verifies it
        ↓
PAM returns success or failure
```

`account include login` checks whether the authenticated account may currently
log in. `password include login` supplies the normal password-changing rules.
`session include login` opens the actual login session and participates in
systemd-logind, runtime-directory, resource-limit, and session lifecycle setup.

The GNOME Keyring password hook uses `use_authtok`, which means it reuses the
password already obtained by PAM rather than displaying another password
prompt. The session hook uses `auto_start` to start the keyring daemon.

The keyring lines are `optional`: a keyring problem should not normally reject
an otherwise valid Linux login. The leading `-` also suppresses noisy failures
if an optional module is unavailable.

The file retains optional KWallet hooks for compatibility, but GNOME Keyring is
the active secret store in this setup.

## GNOME Keyring

GNOME Keyring is an encrypted local secret store. It can hold application
passwords, authentication tokens, network secrets, and entries exposed through
the Secret portal.

It is independent of GNOME Shell. Keeping GNOME Keyring does not mean the GNOME
desktop is still running.

The login flow is:

```text
Ly receives the password
        ↓
PAM verifies the Linux account
        ↓
pam_gnome_keyring receives the same password
        ↓
The login keyring is unlocked
        ↓
The keyring daemon is started for the session
```

For example, without PAM integration an application might ask for a second
keyring password after login. With the current integration, a keyring whose
password matches the Linux login password is unlocked during login.

If keyring unlock fails, the Niri login can still succeed because keyring PAM
integration is optional. An application may then ask to unlock the keyring
later.

## Starting Niri

After PAM approves the login, Ly starts `niri-session`. Using the session
launcher is important because it establishes the environment around Niri,
including integration with:

- The per-user systemd manager
- D-Bus
- XDG session variables
- XDG autostart
- Desktop portals

The process hierarchy is approximately:

```text
ly@tty2.service
└─ Ly
   └─ PAM login session
      └─ niri-session
         └─ Niri
```

A healthy current session appears in `loginctl` as:

```text
Service=ly
Desktop=niri
Type=wayland
State=active
```

## What Niri Starts

Niri reads `~/.config/niri/config.kdl`, which is Stow-linked to
`niri/.config/niri/config.kdl` in this repository. Its startup section launches:

| Process | Purpose |
|---|---|
| Quickshell | Bar, drawers, OSD, lock screen, and system controls |
| Mako | Notifications |
| `xfce-polkit` | Graphical authorization prompts |
| `awww-daemon` | Wallpaper rendering and transitions |
| Waypaper | Restore the selected wallpaper |
| `wl-paste` watchers | Record text and image clipboard history |
| Display helper | Set initial internal-panel brightness |
| `swayidle` | Dimming, locking, monitor power, and suspend |

The startup structure is:

```text
Niri
├─ Matugen → Quickshell
├─ Matugen → Mako
├─ xfce-polkit
├─ awww-daemon
├─ Waypaper restore
├─ text clipboard watcher
├─ image clipboard watcher
├─ initial brightness setup
└─ swayidle
```

Niri launches Quickshell and Mako through
`~/.config/matugen/apply-theme.sh`. The script generates colors from the active
wallpaper and serializes concurrent generation with a lock file. If Matugen or
the wallpaper is unavailable, startup is degraded but not blocked: Quickshell
has fallback colors, Niri's generated include is optional, and Mako can use its
normal configuration.

## PolicyKit And xfce-polkit

PolicyKit, usually called Polkit, controls authorization for privileged actions
requested by desktop applications. PAM and Polkit answer different questions:

| Component | Question |
|---|---|
| PAM | Is this authentication valid? |
| Polkit | May this user perform this privileged action? |
| `xfce-polkit` | How should the graphical authentication prompt be shown? |

Examples of operations that may involve Polkit include formatting a disk,
editing a protected network connection, changing a system service, or mounting
certain storage devices.

An example flow is:

```text
GNOME Disks requests a privileged operation
        ↓
The system service asks Polkit for authorization
        ↓
Polkit decides that authentication is required
        ↓
xfce-polkit displays a password dialog
        ↓
Polkit's PAM policy verifies the password
        ↓
Polkit grants or denies the operation
```

`xfce-polkit` does not grant permission by itself. It supplies the graphical
agent used to collect authentication. Niri starts it explicitly with:

```kdl
spawn-at-startup "/usr/libexec/xfce-polkit"
```

## Desktop Portals

XDG Desktop Portal brokers requests between applications and desktop services.
It is especially important for Flatpak and other sandboxed applications.

Typical portal operations include:

- Opening or saving a file
- Screen sharing
- Opening a URL
- Showing notifications
- Requesting access to protected resources
- Storing and retrieving secrets

The Niri portal preference is:

```ini
[preferred]
default=gnome;gtk;
org.freedesktop.impl.portal.Access=gtk;
org.freedesktop.impl.portal.Notification=gtk;
org.freedesktop.impl.portal.Secret=gnome-keyring;
```

This prefers the GNOME backend generally, uses GTK as fallback, forces GTK for
Access and Notification, and uses GNOME Keyring for Secret.

For example, a sandboxed application may not be able to browse the filesystem
directly:

```text
Application requests a file
        ↓
xdg-desktop-portal receives the request
        ↓
GNOME or GTK backend displays a chooser
        ↓
The user selects a file
        ↓
The portal grants access to that selection
```

`xdg-desktop-portal-gnome` is a reusable backend. Its presence does not mean
GNOME Shell or the GNOME desktop session is running.

## Login Versus Unlock

Initial login and screen unlock are separate security boundaries:

| Operation | Program | PAM service |
|---|---|---|
| Initial login | Ly | `ly` |
| Unlock existing session | Quickshell lock shell | `quickshell-lock` |

The lock PAM policy is deliberately small:

```pam
auth required pam_unix.so
account required pam_unix.so
```

It verifies the local password and account but does not open another login
session or start another keyring daemon.

```text
Ly login
→ creates a Niri session
→ opens a logind session
→ starts and unlocks the keyring

Quickshell unlock
→ verifies the existing user's password
→ releases the existing Wayland session lock
→ does not create another login session
```

## How The Lock Becomes Secure

A window that merely looks like a lock screen is insufficient. The compositor
could still focus another window or accept input elsewhere. The Quickshell lock
uses the Wayland session-lock protocol so Niri enforces the lock.

The lock path is:

```text
lock request
└─ lock.sh
   └─ quickshell-lock-shell.service
      └─ LockShell.qml
         ├─ acquires the Wayland session lock
         └─ reports secure state through Quickshell IPC
```

`lock.sh` serializes simultaneous requests, starts or reuses the exact systemd
user service, reads its process ID, and polls that process through IPC. It only
returns success when `lock isSecure` reports `true`.

If the lock surface appears but does not acquire the Wayland protocol lock,
`lock.sh` returns failure and stops a service started by that attempt. Visual
appearance alone is never treated as proof of security.

## Idle And Suspend Behavior

Niri starts `swayidle` with these approximate stages:

| Idle time | Action |
|---|---|
| 270 seconds | Save brightness and dim to 10% |
| 300 seconds | Acquire the secure lock |
| 400 seconds | Power off monitors |
| 500 seconds | Request suspend |

Activity restores brightness or powers monitors back on as applicable.

Suspend has an additional system-level precondition:

```text
systemd-suspend.service
└─ quickshell-secure-suspend
   └─ locate the active local Wayland session
      └─ quickshell-secure-lock.service
         └─ lock.sh
            └─ confirmed Wayland session lock
```

If the active session cannot obtain a confirmed lock, suspend is aborted. For
example, if the Quickshell lock process crashes while the lid-close suspend is
being prepared, the helper logs an error, attempts a critical notification, and
returns failure instead of allowing the machine to suspend unlocked.

## Removed Packages

The cleanup removed the complete GNOME login and session path, including:

- `gdm3`
- `gnome-shell`
- `gnome-control-center`
- `gnome-settings-daemon`
- `gnome-online-accounts`
- `gnome-session-bin`
- `gnome-session-common`
- GDM libraries and introspection files
- Mutter libraries and common data
- GNOME Shell's GJS and Mozilla JavaScript runtime
- GNOME Control Center support data
- GNOME Settings Daemon common data
- The unused GNOME Online Accounts backend

Mutter is GNOME Shell's compositor. Niri is now the compositor, so the GNOME
Shell and Mutter session stack is not part of the desktop.

## Retained Packages

The setup intentionally retained:

- `xdg-desktop-portal-gnome`
- `xdg-desktop-portal-gtk`
- `gnome-keyring`
- `libpam-gnome-keyring`
- `xfce-polkit`
- Nautilus, GVFS, and GVFS backends
- PipeWire audio
- Power Profiles Daemon
- `switcheroo-control`
- Printing support
- GNOME Disks
- GNOME Snapshot
- GNOME Clocks
- Seahorse
- Papers
- Ptyxis

These are independent applications and services. A GNOME application does not
require GNOME Shell to be the active desktop. Similarly, retaining the GNOME
portal and keyring does not restore the removed GNOME session.

Ptyxis was retained because package simulations showed that removing it would
cause APT to install GNOME Terminal and Yelp as a replacement provider for
`x-terminal-emulator`.

## APT Autoremove

APT tracks dependencies declared by Debian packages. It cannot always detect
libraries needed by manually installed software such as an upstream binary.

APT understands:

```text
Debian package A declares a dependency on Debian package B
```

It may not understand:

```text
Manually installed program A loads library B at runtime
```

The remaining autoremove proposal contained a mixture of probable leftovers and
general-purpose components, including image loaders, HEIF and JPEG XL thumbnail
support, WebP Pixbuf support, input-emulation libraries, FreeRDP libraries, GTK
introspection packages, and mobile broadband data. They were left installed to
avoid removing optional capabilities used by manually installed software.

They do not cause the removed GNOME desktop to run. Their main costs are disk
space and occasional package updates.

Use this workflow in the future:

```bash
apt-get --dry-run autoremove
```

Read the complete proposal. Run the real command only when every removal is
understood:

```bash
sudo apt autoremove
```

Do not treat `apt autoremove` as forbidden forever; treat it as a command whose
proposal must be reviewed on a machine with manually installed software.

## Configuration Ownership

Most top-level repository directories are GNU Stow packages. For example:

```text
Repository: niri/.config/niri/config.kdl
Home path:  ~/.config/niri/config.kdl
```

The home path is normally a symlink into the repository, so changing the
repository file changes what Niri reads.

The `system/` directory is different. It contains source copies for root-owned
destinations:

```text
Repository: system/etc/pam.d/ly
Installed:  /etc/pam.d/ly
```

Editing the repository copy does not update the installed copy. Reinstall it
explicitly:

```bash
sudo install --backup=numbered -D -o root -g root -m 0644 \
  system/etc/pam.d/ly \
  /etc/pam.d/ly
```

The same rule applies to `system/etc/ly/config.ini`. Root-owned copies are used
because authentication and system policy must not be writable indirectly
through ordinary user-owned symlinks.

Ly itself is not managed by APT. `/usr/bin/ly`, its upstream support files, and
`/usr/lib/systemd/system/ly@.service` must be updated by rebuilding and
reinstalling the pinned upstream project. The repository owns only the custom
configuration and PAM policy.

## Common Scenarios

### Normal Login

```text
Power on
→ systemd starts Ly on TTY2
→ username and password are entered
→ PAM validates the password and account
→ GNOME Keyring unlocks
→ Ly starts niri-session
→ Niri starts the desktop components
```

### Incorrect Password

```text
Incorrect password entered in Ly
→ PAM rejects authentication
→ no Niri session is created
→ the keyring is not unlocked
→ Ly remains at the login screen
```

### Logging Out

```text
Niri exits
→ the Wayland session ends
→ PAM session cleanup runs
→ session processes stop as appropriate
→ Ly displays the login interface again
```

### Locking And Unlocking

```text
Lock requested
→ Quickshell acquires the Wayland session lock
→ quickshell-lock PAM verifies the password
→ the existing session lock is released
```

Unlocking does not restart Niri or create another login session.

### Privileged Graphical Operation

```text
GNOME Disks requests a protected operation
→ Polkit evaluates the request
→ xfce-polkit displays an authentication dialog
→ PAM checks the password for Polkit
→ the operation is allowed or denied
```

### Sandboxed File Selection

```text
Application requests a file
→ xdg-desktop-portal handles the request
→ GNOME or GTK portal backend displays the chooser
→ the selected file is granted to the application
```

### Lock Failure During Suspend

```text
Suspend requested
→ secure-suspend helper finds the Wayland session
→ Quickshell lock fails to acquire protocol security
→ helper returns failure
→ suspend is aborted rather than resuming unlocked
```

### Broken Graphical Login

```text
Switch to Ctrl+Alt+F1
→ log in at the recovery console
→ inspect Ly and its logs
→ validate configuration
→ repair Ly, PAM, or the Niri session entry
```

Useful diagnostics include:

```bash
systemctl status ly@tty2.service
journalctl -u ly@tty2.service
/usr/bin/ly --validate-config /etc/ly/config.ini
test -f /usr/share/wayland-sessions/niri.desktop
loginctl list-sessions
```

Ly's session output is also available at:

```text
~/.local/state/ly-session.log
```

## Returning To GDM

GDM has been purged, so it must be reinstalled before it can be re-enabled:

```bash
sudo apt install gdm3
sudo systemctl disable ly@tty2.service
sudo systemctl enable gdm.service
sudo reboot
```

Perform display-manager changes from TTY1 rather than from inside the graphical
session being replaced.

## Validation

Relevant checks for the current setup are:

```bash
niri validate -c niri/.config/niri/config.kdl
/usr/bin/ly --validate-config system/etc/ly/config.ini
systemctl is-enabled ly@tty2.service
systemctl is-active ly@tty2.service
systemctl is-enabled getty@tty1.service
systemctl --user is-active gnome-keyring-daemon.service
systemctl --user is-active xdg-desktop-portal.service
systemctl --user is-active xdg-desktop-portal-gnome.service
systemctl --user is-active xdg-desktop-portal-gtk.service
pgrep -a xfce-polkit
```

At migration time, these checks passed, the tracked Ly and PAM files matched
their installed copies, no systemd units were failed, and the
login/logout/login cycle worked. This is a historical migration result, not a
claim about the current state of every unrelated system or user unit.

Validation proves the tested state, not that future upgrades can never change
behavior. Changes to Ubuntu, Niri, Quickshell, Ly, PAM, portals, or packages can
require new validation.

## Short Mental Model

The system can be remembered as:

```text
systemd starts Ly
Ly asks PAM to authenticate the login
PAM checks the account and unlocks GNOME Keyring
Ly starts niri-session
Niri starts the desktop components
Portals connect applications to desktop services
Polkit authorizes privileged graphical actions
Quickshell securely locks the existing session
TTY1 remains available if the graphical path fails
```

GDM and GNOME Shell are no longer part of this chain. GNOME Keyring, portals,
and selected GNOME applications remain because they are useful independent
components.
