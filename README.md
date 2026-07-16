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
| `thunar`, `pavucontrol`, `blueman` | File, audio, and Bluetooth utilities |
| `brightnessctl`, `wpctl`, `playerctl` | Brightness, audio, and media controls |
| `jq`, `lm-sensors`, `upower` | System, temperature, and battery telemetry |
| `powerprofilesctl`, `asusctl`, `supergfxctl` | ASUS laptop power and GPU controls |
| JetBrains Mono Nerd Font, Papirus | Interface font and icon theme |

The ASUS power panel is machine-specific and expects `BAT1`, output `eDP-1`, and 2880x1800 modes at 60 Hz and 120 Hz. `rog-control-center` is optional for editing fan curves.

## Contents

| Config | Description |
|--------|-------------|
| Niri | Scrollable tiling, window rules, startup services, and keybindings |
| Quickshell | Workspaces, focused window, clock, media, system monitor, lock screen, and power/fan panels |
| Ghostty | Box theme with transparency and blur |
| Rofi | Dark application launcher with Papirus icons |
| Mako | Compact notifications with urgency-colored borders |
| SwayOSD | Hardware-key overlays |
| Waypaper | Wallpaper picker using the `awww` backend |
| Wlogout | Styled logout and power actions |
| Neovim | Lua configuration using `lazy.nvim`, Snacks, Oil, Neogit, and Gitsigns |
| Zsh | Oh My Zsh, autosuggestions, syntax highlighting, and Starship |
| Tmux | Vi copy mode, mouse support, and a minimal status line |
| Fastfetch | Custom system-information layout and ASCII art |

The `sway/` and `waybar/` directories are retained as legacy alternatives; the active desktop uses Niri and Quickshell.

## Keymaps

> `Mod` is the Super/Windows key.

### General

| Keybind | Action |
|---------|--------|
| `Mod+Return` | Open Ghostty |
| `Mod+D` | Open Rofi |
| `Mod+E` | Open Thunar |
| `Mod+W` | Open Waypaper |
| `Super+Alt+L` | Lock the session |
| `Mod+Q` | Close the focused window |
| `Mod+O` | Toggle the Niri overview |
| `F6` | Take a screenshot |

### Window Management

| Keybind | Action |
|---------|--------|
| `Mod+H/J/K/L` | Focus left/down/up/right |
| `Mod+Ctrl+H/J/K/L` | Move a column or window |
| `Mod+R` / `Mod+Shift+R` | Cycle column widths |
| `Mod+F` | Maximize the current column |
| `Mod+Shift+F` | Toggle fullscreen |
| `Mod+V` | Toggle floating |
| `Mod+Shift+W` | Toggle tabbed columns |

### Workspaces

| Keybind | Action |
|---------|--------|
| `Mod+U` / `Mod+I` | Focus workspace down/up |
| `Mod+Ctrl+U/I` | Move the current column between workspaces |
| `Mod+1-9` | Focus a numbered workspace |
| `Mod+Shift+1-9` | Move the current column to a numbered workspace |

Media keys control playback through `playerctl` and display volume, microphone, and brightness changes through SwayOSD.

## Usage

The repository uses a GNU Stow package layout. Clone it into `~/dotfiles`, then link the packages you want:

```bash
git clone git@github.com:FireNaruto3/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow niri quickshell ghostty nvim rofi mako swayosd wlogout \
  fastfetch starship tmux zsh waypaper gtklock autostart
```

Wallpapers remain in `~/dotfiles/wallpapers` because several configs reference that directory directly. Some files also contain `/home/jonathan` paths and should be adjusted before using the configuration under another account.
