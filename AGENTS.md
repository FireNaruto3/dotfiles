# Repository Notes

## Layout and Deployment

- This is a GNU Stow tree: each top-level package mirrors paths under `$HOME` (for example, `niri/.config/niri/config.kdl` becomes `~/.config/niri/config.kdl`). Edit the repository copy, not an unrelated file under `~/.config`.
- Niri and Quickshell are the active desktop. `sway/` and `waybar/` are retained legacy alternatives; do not update them for active-desktop changes unless explicitly requested.
- `system/` is not a Stow package. Its files are copied to `/etc` or `/usr` as root-owned files using the commands and modes in `README.md`; sleep-policy changes require reinstallation and `systemctl reload systemd-logind.service`.
- Wallpapers intentionally remain at `~/dotfiles/wallpapers`; use `$HOME`, `~`, or paths relative to the referring config rather than account-specific absolute paths.

## Coupled Behavior

- `quickshell/.config/quickshell/shell.qml` is the normal shell entrypoint. `LockShell.qml` is a separate Quickshell instance started by `scripts/lock.sh`.
- Keep the lock acquisition handshake intact: `lock.sh` starts `LockShell.qml`, polls the `lock isSecure` IPC method, and falls back to `gtklock` if the Wayland session-lock protocol is not secured within roughly 10 seconds. Niri keybindings, `swayidle`, and wlogout call `~/.config/quickshell/scripts/lock.sh`.
- Quickshell data objects consume JSON emitted by `scripts/*-stats.sh` and `power-state.sh`. When changing a JSON key or type, update its corresponding QML properties in `SystemData.qml` or `PowerData.qml` in the same change.
- Fan stats run only while the fan panel is visible. The bar launches the external Resources application instead of polling CPU/GPU resource stats itself.
- Keep `README.md` synchronized when changing documented packages, power behavior, installation steps, or Niri keybindings.

## Machine-Specific Assumptions

- Several settings are deliberately machine-specific: the Samsung ATNA40CU05-0 panel with 2880x1800 modes and ASUS utilities/devices. Connector, backlight, DRM card, and system-battery names are discovered at runtime because their numeric suffixes change with GPU probe order. Search all Niri, Quickshell, and systemd references before changing one of these assumptions.
- `system/usr/lib/systemd/system-sleep/asus-keyboard-backlight` must remain executable when installed; it saves/restores `leds:asus::kbd_backlight` around sleep because firmware resets it after hibernation.

## Focused Checks

- Validate Niri config: `niri validate -c niri/.config/niri/config.kdl`.
- Syntax-check Quickshell helpers: `bash -n quickshell/.config/quickshell/scripts/*.sh`.
- Check the POSIX-shell paths specifically: `sh -n quickshell/.config/quickshell/scripts/lock.sh system/usr/lib/systemd/system-sleep/asus-keyboard-backlight system/usr/lib/systemd/system-sleep/asus-power-profile-sync system/usr/libexec/asus-power-profile-sync`.
- There is no repository-wide build, test, lint, or CI command. Quickshell validation is runtime- and hardware-dependent; do not launch the lock shell as a casual syntax check because it attempts to acquire the session lock.
