# Repository Notes

## Layout and Deployment

- This is a GNU Stow tree: each top-level package mirrors paths under `$HOME` (for example, `niri/.config/niri/config.kdl` becomes `~/.config/niri/config.kdl`). Edit the repository copy, not an unrelated file under `~/.config`.
- Niri and Quickshell are the active desktop and provide the bar and OSD. Do not reintroduce retired Waybar or SwayOSD packages without an explicit request.
- `system/` is not a Stow package. Its files are copied to `/etc` or `/usr` as root-owned files using the commands and modes in `README.md`; sleep-policy changes require reinstallation and `systemctl reload systemd-logind.service`.
- Wallpapers intentionally remain at `~/dotfiles/wallpapers`; use `$HOME`, `~`, or paths relative to the referring config rather than account-specific absolute paths.

## Coupled Behavior

- `quickshell/.config/quickshell/shell.qml` is the normal shell entrypoint. `LockShell.qml` runs in a separate Quickshell instance owned by `quickshell-lock-shell.service`; `scripts/lock.sh` starts that unit and verifies it through IPC.
- Keep the lock acquisition handshake intact: `lock.sh` serializes requests, starts or reuses `quickshell-lock-shell.service`, polls its exact process with the `lock isSecure` IPC method, and returns an error if the Wayland session-lock protocol is not secured within roughly 10 seconds. Niri keybindings, `swayidle`, and wlogout call `~/.config/quickshell/scripts/lock.sh`; the system suspend precondition calls it through `quickshell-secure-lock.service`.
- Quickshell data objects consume JSON emitted by `scripts/*-stats.sh` and `power-state.sh`. When changing a JSON key or type, update its corresponding QML properties in `SystemData.qml` or `PowerData.qml` in the same change.
- The bar polls lightweight CPU, AMD `k10temp/Tctl`, and RAM data for its indicators; detailed monitoring remains in the external Resources application. Both CPU and RAM buttons toggle Resources.
- Keep the vertical and horizontal bar control order, Quick Settings page order, Niri `Mod+S` binding, and drawer selection/highlight behavior synchronized. The dedicated Quick Settings button follows clipboard; pages default to Bluetooth and continue with Network, Audio, and Displays.
- `asus-power-profile-sync.service` owns the reproducible ASUS defaults: Balanced on AC and Quiet on battery. Manual Quickshell selections are temporary because `asusd` power-source events and the resume hook can reapply those defaults.
- Keep `README.md` synchronized when changing documented packages, power behavior, installation steps, or Niri keybindings.
- Keep publication metadata (`LICENSE`, `SECURITY.md`, and `.github/workflows/checks.yml`) synchronized with repository scope. The MIT grant covers code and configuration, not `wallpapers/` or `screenshots/`.
- Matugen writes generated desktop files to the fixed `~/.cache/matugen` path used by Niri, Quickshell, Rofi, Waypaper, and Wlogout. Keep producers and consumers synchronized; this setup does not relocate those files with `XDG_CACHE_HOME`.

## Machine-Specific Assumptions

- Several settings are deliberately machine-specific: the Samsung ATNA40CU05-0 panel with 2880x1800 modes and ASUS utilities/devices. Connector, backlight, DRM card, and system-battery names are discovered at runtime because their numeric suffixes change with GPU probe order. Search all Niri, Quickshell, and systemd references before changing one of these assumptions.
- Files under `system/usr/lib/systemd/system-sleep/` must remain executable when installed. `asus-keyboard-backlight` saves/restores `leds:asus::kbd_backlight`; `asus-power-profile-sync` reapplies the source-dependent profile after resume; `quiet-resume-console` temporarily suppresses non-critical console messages while graphics are unavailable.

## Focused Checks

- Validate Niri config: `niri validate -c niri/.config/niri/config.kdl`.
- Syntax-check Quickshell helpers: `bash -n quickshell/.config/quickshell/scripts/*.sh`.
- Check the POSIX-shell paths specifically: `sh -n quickshell/.config/quickshell/scripts/launch-wlogout.sh quickshell/.config/quickshell/scripts/lock.sh system/usr/lib/systemd/system-sleep/asus-keyboard-backlight system/usr/lib/systemd/system-sleep/asus-power-profile-sync system/usr/lib/systemd/system-sleep/quiet-resume-console system/usr/libexec/asus-power-profile-sync system/usr/libexec/quickshell-secure-suspend`.
- GitHub Actions runs shell syntax, ShellCheck, helper tests, whitespace, JSON, and publication checks. Keep every screenshot referenced by `README.md` in the publication invariant list. Quickshell validation remains runtime- and hardware-dependent; do not launch the lock shell as a casual syntax check because it attempts to acquire the session lock.
