# Jonathan's Dotfiles

A dark, minimal Wayland rice built around Niri and Quickshell. The interface uses a blue-gray palette with cyan, lavender, green, and yellow accents, JetBrains Mono Nerd Font, and Papirus icons.

## Screenshots

Screenshots will be added here.

## Requirements

| Package | Purpose |
|---------|---------|
| `niri` | Scrollable-tiling Wayland compositor |
| `quickshell` | Top bar, dashboards, lock screen, and power controls |
| `ghostty` | Terminal emulator |
| `rofi` | Application launcher |
| `mako` | Notifications and do-not-disturb mode |
| `swayosd` | Volume, microphone, and brightness overlays |
| `swayidle` | Idle dimming, locking, display power, and suspend handling |
| `gtklock` | Fallback locker when Quickshell cannot acquire session lock |
| `waypaper` + `awww` | Wallpaper selection and restoration |
| `wlogout` | Session and power menu |
| `resources` | System resource monitor launched from the bar |
| `thunar`, `pavucontrol`, `blueman` | File, audio, and Bluetooth utilities |
| `brightnessctl`, `wpctl`, `playerctl` | Brightness, audio, and media controls |
| `jq`, `lm-sensors`, `upower` | System, temperature, and battery telemetry |
| `powerprofilesctl`, `asusctl`, `supergfxctl` | ASUS laptop power controls and GPU-aware telemetry |
| JetBrains Mono Nerd Font, Papirus | Interface font and icon theme |

The ASUS power panel is machine-specific and expects the Samsung ATNA40CU05-0 internal panel with 2880x1800 modes at 60 Hz and 120 Hz. Runtime helpers discover the panel connector, backlight, and system battery rather than relying on probe-order names such as `eDP-1`, `amdgpu_bl1`, or `BAT1`. The panel provides manual active-profile control through `powerprofilesctl`; ASUS fan curves are managed with `asusctl` rather than ROG Control Center.

## Contents

| Config | Description |
|--------|-------------|
| Niri | Scrollable tiling, window rules, startup services, and keybindings |
| Quickshell | Workspaces, focused window, clock, media, resource-monitor launcher, battery-aware lock screen, and power/fan panels |
| Systemd | Unified sleep policy and ASUS keyboard-backlight restoration across resume |
| Ghostty | Box theme with transparency and blur |
| Rofi | Dark application launcher with Papirus icons |
| Mako | Compact notifications with urgency-colored borders |
| SwayOSD | Hardware-key overlays |
| Waypaper | Wallpaper picker using the `awww` backend |
| Wlogout | Styled logout and power actions |
| Neovim | Lua configuration using `lazy.nvim`, Snacks, Oil, Neogit, and Gitsigns |
| Zsh | Oh My Zsh, syntax highlighting, and Starship |
| Tmux | Vi copy mode, mouse support, and a minimal status line |
| Fastfetch | Custom system-information layout and ASCII art |
| OpenCode | Model selection and global engineering instructions |

The `sway/` and `waybar/` directories are retained as legacy alternatives; the active desktop uses Niri and Quickshell.

## Power Behavior

Lid close, the physical power or sleep key, the lock-screen **Sleep** action, and the idle timeout all suspend first and hibernate after 30 minutes. This policy applies on battery and AC power, while a docked lid close is ignored. A system-sleep hook preserves the ASUS keyboard-backlight level across suspend and hibernation.

The lock screen uses a 12-hour clock with AM/PM, displays live battery percentage, and provides restart, sleep, logout, and power-off actions.

### Fan Curves

The fan panel is monitor-only and polls the ASUS CPU, GPU, and MID fan RPM sensors once per second while visible. Every card continuously shows measured RPM, including a valid stopped state. CPU and GPU show their curve target as secondary information when an enabled custom curve and controlling temperature are available; otherwise they identify firmware control or unavailable telemetry. MID is RPM-only because this laptop exposes its fan speed but not its controlling temperature.

NVIDIA temperature is read only in dGPU MUX mode, where NVIDIA cannot runtime-suspend. Integrated mode reports the dGPU disabled, while Hybrid mode reports active or suspended without querying NVIDIA telemetry, so polling cannot wake the dGPU or delay suspension. Live RPM and temperature data updates once per second; ASUS profile and curve metadata updates every 15 seconds to avoid repeated daemon calls. The cards are persistent rather than rebuilt on each telemetry sample, so polling cannot disrupt hover or click state. Use `asusctl` to manage custom curves:

```bash
# Inspect one profile.
asusctl fan-curve --mod-profile Balanced

# Enable or disable all custom curves for one profile.
asusctl fan-curve --mod-profile Balanced --enable-fan-curves true
asusctl fan-curve --mod-profile Balanced --enable-fan-curves false

# Restore the active profile's firmware-default curves.
asusctl fan-curve --default

# Set one eight-point curve.
asusctl fan-curve --mod-profile Balanced --fan cpu \
  --data '30c:1%,49c:2%,59c:10%,69c:20%,79c:35%,89c:55%,99c:75%,109c:100%'
```

## Keymaps

> `Mod` is the Super/Windows key.

Directional bindings follow a consistent hierarchy: `Mod` focuses, `Mod+Shift`
moves the focused window or column, `Mod+Ctrl` focuses another monitor, and
`Mod+Ctrl+Shift` moves across monitors or reorders an entire workspace.

### General

| Keybind | Action |
|---------|--------|
| `Mod+Shift+/` | Show the Niri hotkey overlay |
| `Mod+Return` | Open Ghostty |
| `Mod+D` | Open Rofi |
| `Mod+E` | Open Thunar |
| `Mod+W` | Open Waypaper |
| `Super+Alt+L` | Lock the session |
| `Mod+Q` | Close the focused window |
| `Mod+O` | Toggle the Niri overview |
| `F6` | Take a screenshot |

### Focus and Movement

| Keybind | Action |
|---------|--------|
| `Mod+H/J/K/L` | Focus the column left/right or window down/up |
| `Mod+Shift+H/J/K/L` | Move the column left/right or window down/up |
| `Mod+Home/End` | Focus the first/last column |
| `Mod+Shift+Home/End` | Move the column to the first/last position |

### Columns and Windows

| Keybind | Action |
|---------|--------|
| `Mod+[` | Consume into or expel from the column on the left |
| `Mod+]` | Consume into or expel from the column on the right |
| `Mod+,` | Consume one window from the right into the focused column |
| `Mod+.` | Expel the bottom window from the focused column to the right |
| `Mod+R` | Cycle forward through preset column widths |
| `Mod+Shift+R` | Cycle backward through preset column widths |
| `Mod+Ctrl+Shift+R` | Cycle through preset window heights |
| `Mod+Ctrl+R` | Reset the focused window height |
| `Mod+F` | Maximize the current column |
| `Mod+Shift+F` | Toggle fullscreen |
| `Mod+M` | Maximize the window to the screen edges |
| `Mod+Ctrl+F` | Expand the column to the available width |
| `Mod+C` | Center the focused column |
| `Mod+Ctrl+C` | Center all visible columns |
| `Mod+-` / `Mod+=` | Decrease/increase the column width by 10% |
| `Mod+Shift+-` / `Mod+Shift+=` | Decrease/increase the window height by 10% |
| `Mod+V` | Toggle the focused window between floating and tiled |
| `Mod+Shift+V` | Switch focus between floating and tiled windows |
| `Mod+Shift+W` | Toggle tabbed columns |

### Workspaces

| Keybind | Action |
|---------|--------|
| `Mod+U` / `Mod+I` | Focus workspace down/up |
| `Mod+Shift+U/I` | Move the current column to the workspace down/up |
| `Mod+Ctrl+Shift+U/I` | Reorder the entire workspace down/up |
| `Mod+1-9` | Focus a numbered workspace |
| `Mod+Shift+1-9` | Move the current column to a numbered workspace |

### Monitors

| Keybind | Action |
|---------|--------|
| `Mod+Ctrl+H/J/K/L` | Focus the monitor left/down/up/right |
| `Mod+Ctrl+Arrow keys` | Focus a monitor by direction |
| `Mod+Ctrl+Shift+H/J/K/L` | Move the current column to a monitor |
| `Mod+Ctrl+Shift+Arrow keys` | Move the current column to a monitor |

### Mouse Navigation

| Keybind | Action |
|---------|--------|
| `Mod+Wheel up/down` | Focus the workspace up/down |
| `Mod+Shift+Wheel up/down` | Move the current column to the workspace up/down |
| `Mod+Wheel left/right` | Focus the column left/right |
| `Mod+Shift+Wheel left/right` | Move the column left/right |

### Audio, Brightness, and Media

These hardware keys remain active while the session is locked.

| Keybind | Action |
|---------|--------|
| `XF86AudioRaiseVolume` (volume up) | Raise the output volume through SwayOSD |
| `XF86AudioLowerVolume` (volume down) | Lower the output volume through SwayOSD |
| `XF86AudioMute` (volume mute) | Toggle output mute through SwayOSD |
| `XF86AudioMicMute` (microphone mute) | Toggle microphone mute through SwayOSD |
| `XF86MonBrightnessUp` (brightness up) | Raise display brightness through SwayOSD |
| `XF86MonBrightnessDown` (brightness down) | Lower display brightness through SwayOSD |
| `XF86AudioPlay` / `XF86AudioPause` | Toggle playback through `playerctl` |
| `XF86AudioStop` | Stop playback through `playerctl` |
| `XF86AudioPrev` | Play the previous track through `playerctl` |
| `XF86AudioNext` | Play the next track through `playerctl` |

### Session and Displays

| Keybind | Action |
|---------|--------|
| `Mod+Escape` | Toggle whether applications can inhibit Niri shortcuts |
| `Mod+Shift+P` | Power off all monitors |
| `Ctrl+Alt+Delete` | Quit Niri |

## Usage

The repository uses a GNU Stow package layout. Clone it into `~/dotfiles`, then link the packages you want:

```bash
git clone git@github.com:FireNaruto3/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow niri quickshell ghostty nvim rofi mako swayosd wlogout \
  fastfetch starship tmux zsh waypaper gtklock autostart opencode
```

Keep the repository at `~/dotfiles`: wallpaper files and the Fastfetch logo are referenced through that conventional location, while account-specific paths use `$HOME` or `~`. If you clone elsewhere, update those `~/dotfiles` references before starting the desktop.

System-wide files are tracked under `system/` and installed as root-owned copies rather than user-writable symlinks:

```bash
sudo install -D -o root -g root -m 0644 \
  system/etc/systemd/logind.conf.d/90-sleep-policy.conf \
  /etc/systemd/logind.conf.d/90-sleep-policy.conf

sudo install -D -o root -g root -m 0644 \
  system/etc/systemd/sleep.conf.d/90-hibernate-delay.conf \
  /etc/systemd/sleep.conf.d/90-hibernate-delay.conf

sudo install -D -o root -g root -m 0755 \
  system/usr/lib/systemd/system-sleep/asus-keyboard-backlight \
  /usr/lib/systemd/system-sleep/asus-keyboard-backlight

sudo install -D -o root -g root -m 0644 \
  system/etc/supergfxd.conf \
  /etc/supergfxd.conf

sudo systemctl daemon-reload
sudo systemctl reload systemd-logind.service
sudo systemctl restart supergfxd.service
```

Hibernation uses systemd's dynamic `HibernateLocation` EFI variable with the
active `/swap.img`; no static `resume=` or `resume_offset=` kernel parameters
are installed. On an ordinary boot without a hibernation image,
`/sys/power/resume` and `/sys/power/resume_offset` should both be zero.

Wallpapers remain in `~/dotfiles/wallpapers` because the desktop and lock-screen configs reference that directory. Wallpaper paths use the current user's home directory and do not need account-specific changes.
